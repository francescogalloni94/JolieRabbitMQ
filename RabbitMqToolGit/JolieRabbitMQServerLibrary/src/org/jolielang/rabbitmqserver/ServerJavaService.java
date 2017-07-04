package org.jolielang.rabbitmqserver;


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
import java.util.Map;
import java.util.concurrent.TimeoutException;
import java.util.logging.Level;
import java.util.logging.Logger;
import jolie.net.CommMessage;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.ValueVector;
import org.jolielang.rabbitmqutil.QueueMessage;




public class ServerJavaService extends JavaService {
    ConnectionFactory factory;
    Connection connection;
    Channel channel;
    ArrayList<String> queueNames;
    ArrayList<DefaultConsumer> consumers;
    final String splitToken="#";
  
    
    
    
    public void configure(Value config){
        String apiType=config.getFirstChild("apiType").strValue();
        String hostName=config.getFirstChild("hostName").strValue();
        factory=new ConnectionFactory();
        factory.setHost(hostName);
        queueNames=new ArrayList<String>();
        try {
            connection=factory.newConnection();
            channel=connection.createChannel();
            String location=config.getFirstChild("portMetaData").getFirstChild("location").strValue();
            channel.exchangeDeclare(location,"direct");
            ValueVector interfaces=config.getFirstChild("portMetaData").getChildren("interfaces");
            for(int j=0;j<interfaces.size();j++){
            ValueVector operations=interfaces.get(j).getChildren("operations");   
            for(int i=0;i<operations.size();i++){
                String operationName=operations.get(i).getFirstChild("operation_name").strValue();
                String name=location+splitToken+operationName;
                queueNames.add(name);
                channel.queueDeclare(name, true,false,false,null);
                channel.queueBind(name,location,name);
                 
                
             }
            }
            
          if(apiType.equalsIgnoreCase("push")){
              startPush();
          }
          if(apiType.equalsIgnoreCase("pull")){
              int maxThread=config.getFirstChild("maxThread").intValue();
              long millisPullRange=config.getFirstChild("millisPullRange").longValue();
              startPull(maxThread,millisPullRange);
          }
            
        } catch (IOException ex) {
            Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
        } catch (TimeoutException ex) {
            Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
        }
        
    }
    
    
    
    
    
    private void startPush(){
           consumers=new ArrayList<DefaultConsumer>();
            for(int i=0;i<queueNames.size();i++){
                try {
                    final String queueName=queueNames.get(i);
                    DefaultConsumer consumer=new DefaultConsumer(channel){
                        @Override
                        public void handleDelivery (String consumerTag, Envelope envelope,
                                AMQP.BasicProperties properties, byte[] body) throws UnsupportedEncodingException
                        {
                            String id="";
                            Value response=null;
                            byte [] data = Base64.getDecoder().decode(new String(body));
                            try{
                                ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
                                response= (Value) ois.readObject();
                                if(response.getFirstChild("queueID")!=null){
                                id=response.getFirstChild("queueID").strValue();
                                
                                }
                                response=response.getFirstChild("message");
                                ois.close();
                            }catch(IOException e){
                                
                            } catch (ClassNotFoundException ex) {
                                Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
                            }
                            
                            String[] split=queueName.split(splitToken);
                            if(!id.equals("")){
                                //uniqueIds.put(split[3], id);
                            }
                            CommMessage request=CommMessage.createRequest(split[1],"/", response);
                            sendMessage(request);
                            
                            
                            
                        }
                    };
                    consumers.add(consumer);
                    channel.basicConsume(queueName, true, consumer);
                } catch (IOException ex) {
                    Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
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
                Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
            }
        }
    }
    
    
    
    
    private void getMessage(int maxThread){
        
        boolean message=true;
        while(message){
            int count=0;
            for(int i=0;i<queueNames.size();i++){
             if(ManagementFactory.getThreadMXBean().getThreadCount()<maxThread)
             {
                try {
            
                    boolean autoAck=false;
                    GetResponse response=null;
                    response=channel.basicGet(queueNames.get(i), autoAck);
                    if(response==null){
                        count++;
                    }
                    else{
                           String id="";
                           byte[] body = response.getBody();
                           long deliveryTag = response.getEnvelope().getDeliveryTag();
                           QueueMessage callback=null;
                           byte [] data = Base64.getDecoder().decode(new String(body));
                           ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
                           callback = (QueueMessage) ois.readObject();
                           if(!callback.getId().equals("")){
                                id=callback.getId();
                                }
                           Value messageFromQueue=Value.create();
                           messageFromQueue=callback.getMessage();
                           ois.close();
                           
                           String[] split=queueNames.get(i).split(splitToken);
                           CommMessage request=CommMessage.createRequest(split[1],"/",messageFromQueue);
                          if(!id.equals("")){
                              CommMessage operationResponse= sendMessage(request).recvResponseFor(request);
                              QueueMessage operationMessageResponse=new QueueMessage();
                              operationMessageResponse.setMessage(operationResponse.value());
                              operationMessageResponse.setId(id);
                              operationMessageResponse.setSessionToken(callback.getSessionToken());
                              writeResponseOnExchange(operationMessageResponse,split[1],split[0]);
                              
                           }else{
                             sendMessage(request); 
                           }
                           channel.basicAck(deliveryTag, false);
                    }
                } catch (IOException ex) {
                    Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
                } catch (ClassNotFoundException ex) {
                    Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
                }
            }
            }
            if(count==queueNames.size()){
                message=false;
            }
        }
    
    }
    
    private void writeResponseOnExchange(QueueMessage response,String operation,String exchangeName){
        try {
            
            channel.exchangeDeclare(exchangeName,"direct");
            channel.confirmSelect();
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ObjectOutputStream oos = new ObjectOutputStream(baos);
            oos.writeObject(response);
            oos.close();
            String routingKey=exchangeName+splitToken+operation+splitToken+"resp"+splitToken+response.getId();
            String requestString = Base64.getEncoder().encodeToString(baos.toByteArray()); 
            channel.basicPublish(exchangeName, routingKey,null,requestString.getBytes());
            channel.waitForConfirmsOrDie();
            
            
        } catch (IOException ex) {
            Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
        } catch (InterruptedException ex) {
            Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
        }
        
    }
    
    
    
    
}
