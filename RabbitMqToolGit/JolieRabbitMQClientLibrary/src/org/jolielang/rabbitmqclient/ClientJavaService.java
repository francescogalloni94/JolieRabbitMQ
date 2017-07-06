package org.jolielang.rabbitmqclient;


import com.rabbitmq.client.AMQP;
import com.rabbitmq.client.BuiltinExchangeType;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;
import com.rabbitmq.client.DefaultConsumer;
import com.rabbitmq.client.Envelope;
import com.rabbitmq.client.GetResponse;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.io.UnsupportedEncodingException;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.UUID;
import java.util.concurrent.TimeoutException;
import java.util.logging.Level;
import java.util.logging.Logger;
import jolie.net.CommMessage;
import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import org.jolielang.rabbitmqutil.QueueMessage;







public class ClientJavaService extends JavaService {
   
    private Connection connection;
    private ConnectionFactory factory;
    private Channel channel;
    final String splitToken="#";
    ArrayList<String> queueNames;
    ArrayList<String> responseQueues;
    ArrayList<String> responseQueuesNames;
    HashMap<String, String> uniqueIds;
   
    
    
    public void configure(Value request){
        try {
            
            uniqueIds = new HashMap<String, String>();
            responseQueues=new ArrayList<String>();
            responseQueuesNames=new ArrayList<String>();
            queueNames=new ArrayList<String>();
            String hostname=request.getFirstChild("hostname").strValue();
            factory=new ConnectionFactory();
            factory.setHost(hostname);
            connection=factory.newConnection();
            channel=connection.createChannel();
            String portName=request.getFirstChild("name").getFirstChild("name").strValue();
            String location=request.getFirstChild("portData").getFirstChild("location").strValue();
            channel.exchangeDeclare(location,"direct");
            ValueVector interfaces=request.getFirstChild("portData").getChildren("interfaces");
            for(int i=0;i<interfaces.size();i++){
                ValueVector operations=interfaces.get(i).getChildren("operations");
                for(int j=0;j<operations.size();j++){
                String operationName=operations.get(j).getFirstChild("operation_name").strValue();
                String name=location+splitToken+operationName;
                queueNames.add(name);
                channel.queueDeclare(name, true,false,false,null);
                channel.queueBind(name,location,name);
                if(!operations.get(j).getFirstChild("output").getFirstChild("name").strValue().equals("")){
                    String uniqueID = UUID.randomUUID().toString();
                    String responseQueue=location+splitToken+operationName+splitToken+"resp"+splitToken+uniqueID;
                    responseQueues.add(responseQueue);
                    responseQueuesNames.add(operationName);
                    uniqueIds.put(operationName,uniqueID);
                    channel.queueDeclare(responseQueue, true,false,false,null);
                    channel.queueBind(responseQueue,location,responseQueue);
                    
                    
                }
                
                
                }
                
            }
            String apiType=request.getFirstChild("responseApiType").strValue();
            int maxThread=request.getFirstChild("maxThread").intValue();
            long millisPullRange=request.getFirstChild("millisPullRange").longValue();
            QueueListeningThread queueThread=new QueueListeningThread(apiType,maxThread,millisPullRange,responseQueues);
            queueThread.start();
            
            
            
        } catch (IOException ex) {
            Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
        } catch (TimeoutException ex) {
            Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
        }
        
    }
    
  public synchronized void writeOnExchange(Value request){
        try {
            
            
            String exchangeName=request.getFirstChild("exchangeName").strValue();
            String routingKey=request.getFirstChild("routingKey").strValue();
            String[] split=routingKey.split(splitToken);
            QueueMessage message=new QueueMessage();
            message.setMessage(request.getFirstChild("message"));
            if(responseQueuesNames.contains(split[1])){
                message.setId(uniqueIds.get(split[1]));
                String sessionToken = request.getFirstChild("token").strValue();
                message.setSessionToken(sessionToken);
                
                
            }
            channel.exchangeDeclare(exchangeName,"direct");
            channel.confirmSelect();
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ObjectOutputStream oos = new ObjectOutputStream(baos);
            oos.writeObject(message);
            oos.close();
            String requestString = Base64.getEncoder().encodeToString(baos.toByteArray()); 
            channel.basicPublish(exchangeName, routingKey,null,requestString.getBytes());
            channel.waitForConfirmsOrDie();
            
            
        } catch (IOException ex) {
            Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
        } catch (InterruptedException ex) {
            Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
        } 
        
        
    }
  
  
  
    
  private class QueueListeningThread extends Thread{
      private String apiType="";
      private int maxThread;
      private long pullRangeMillis;
      private ArrayList<String> queues;
      ArrayList<DefaultConsumer> consumers;
      
      public QueueListeningThread(String apiType,int maxThread,long pullRangeMillis,ArrayList<String> queues){
             this.apiType=apiType;
             this.maxThread=maxThread;
             this.pullRangeMillis=pullRangeMillis;
             this.queues=queues;
             
             
      }
      
      @Override
      public void run(){
          if(this.apiType.equalsIgnoreCase("pull")){
              startPull(this.maxThread,this.pullRangeMillis);
          }else if(this.apiType.equalsIgnoreCase("push")){
              startPush();
          }
          
      }
      
      private void startPush(){
           consumers=new ArrayList<DefaultConsumer>();
            for(int i=0;i<queues.size();i++){
                try {
                    final String queueName=queues.get(i);
                    DefaultConsumer consumer=new DefaultConsumer(channel){
                        @Override
                        public void handleDelivery (String consumerTag, Envelope envelope,
                                AMQP.BasicProperties properties, byte[] body) throws UnsupportedEncodingException
                        {
                            QueueMessage response=null;
                            byte [] data = Base64.getDecoder().decode(new String(body));
                            try{
                                ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
                                response = (QueueMessage) ois.readObject();
                                ois.close();
                            }catch(IOException e){
                                
                            } catch (ClassNotFoundException ex) {
                                Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
                            }
                            
                            String[] split=queueName.split(splitToken);
                            Value operationCallback=Value.create();
                            operationCallback.getFirstChild("message").deepCopy(response.getMessage());
                            operationCallback.getNewChild("token").setValue(response.getSessionToken());
                            CommMessage request=CommMessage.createRequest("_receiveResponse","/",operationCallback);
                            sendMessage(request);
                            
                            
                            
                        }
                    };
                    consumers.add(consumer);
                    channel.basicConsume(queueName, true, consumer);
                } catch (IOException ex) {
                    Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
       
        
    }
      
     private void startPull(int maxThread,long pullRangeMillis){
        
         while(true){
            
            if(ManagementFactory.getThreadMXBean().getThreadCount()<maxThread){
                getMessage(maxThread);
            }
            try {
                Thread.sleep(pullRangeMillis);
            } catch (InterruptedException ex) {
                Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
            }
        }
    }
     
     private void getMessage(int maxThread){
        
        boolean message=true;
        while(message){
            int count=0;
            for(int i=0;i<queues.size();i++){
             if(ManagementFactory.getThreadMXBean().getThreadCount()<maxThread)
             {
                try {
            
                    boolean autoAck=false;
                    GetResponse response=null;
                    response=channel.basicGet(queues.get(i), autoAck);
                    if(response==null){
                        count++;
                    }
                    else{
                           
                           byte[] body = response.getBody();
                           long deliveryTag = response.getEnvelope().getDeliveryTag();
                           QueueMessage callback=null;
                           byte [] data = Base64.getDecoder().decode(new String(body));
                           ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
                           callback = (QueueMessage) ois.readObject();
                           ois.close();
                           String[] split=queues.get(i).split(splitToken);
                           Value messageFromQueue=Value.create();
                           messageFromQueue.getFirstChild("message").deepCopy(callback.getMessage());
                           messageFromQueue.getNewChild("token").setValue(callback.getSessionToken());
                           CommMessage request=CommMessage.createRequest("_receiveResponse","/",messageFromQueue);
                           sendMessage(request); 
                           
                           channel.basicAck(deliveryTag, false);
                    }
                } catch (IOException ex) {
                    Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
                } catch (ClassNotFoundException ex) {
                    Logger.getLogger(ClientJavaService.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            }
            if(count==queues.size()){
                message=false;
            }
        }
    
    }
     
      
  }
  
  
}
