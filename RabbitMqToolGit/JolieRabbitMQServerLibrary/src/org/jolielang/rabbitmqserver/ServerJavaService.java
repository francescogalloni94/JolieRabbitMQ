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
            try {
            for(int i=0;i<queueNames.size();i++){
               
                    final String queueName=queueNames.get(i);
                    DefaultConsumer consumer=new DefaultConsumer(channel){
                        @Override
                        public void handleDelivery (String consumerTag, Envelope envelope,
                                AMQP.BasicProperties properties, byte[] body) throws UnsupportedEncodingException
                        {
                            ObjectInputStream ois=null;
                            try {
                                String id="";
                                QueueMessage response=null;
                                byte [] data = Base64.getDecoder().decode(new String(body));
                                ois = new ObjectInputStream(new ByteArrayInputStream(data));
                                response= (QueueMessage) ois.readObject();
                                if(!response.getId().equals("")){
                                    id=response.getId();
                                    
                                }
                                ois.close();
                                Value messageFromQueue=Value.create();
                                messageFromQueue=response.getMessage();
                                String[] split=queueName.split(splitToken);
                                CommMessage request=CommMessage.createRequest(split[1],"/",messageFromQueue);
                                if(!id.equals("")){
                                    QueueMessage operationMessageResponse=new QueueMessage();
                                    operationMessageResponse.setId(id);
                                    operationMessageResponse.setSessionToken(response.getSessionToken());
                                    ResponseWaitingThread responseThread=new ResponseWaitingThread(request,operationMessageResponse);
                                    responseThread.configure(split[1],split[0], splitToken, channel);
                                    responseThread.start();
                                }else{
                                    
                                    sendMessage(request);
                                }
                            } catch (IOException ex) {
                                Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
                            } catch (ClassNotFoundException ex) {
                                Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
                            } finally {
                                try {
                                    ois.close();
                                } catch (IOException ex) {
                                    Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
                                }
                            }
                            
                            
                            
                        }
                    };
                    consumers.add(consumer);
                    channel.basicConsume(queueName, true, consumer);
                
            }
       } catch (IOException ex) {
                    Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
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
                              QueueMessage operationMessageResponse=new QueueMessage();
                              operationMessageResponse.setId(id);
                              operationMessageResponse.setSessionToken(callback.getSessionToken());
                              ResponseWaitingThread responseThread=new ResponseWaitingThread(request,operationMessageResponse);
                              responseThread.configure(split[1],split[0], splitToken, channel);
                              responseThread.start();
                              
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
    
    
    
    
    private class ResponseWaitingThread extends Thread{
        private CommMessage request;
        private QueueMessage operationMessageResponse;
        private String operation;
        private String exchangeName;
        private String splitToken;
        private Channel channel;
        
        public ResponseWaitingThread(CommMessage request,QueueMessage operationMessageResponse){
            this.request=request;
            this.operationMessageResponse=operationMessageResponse;
        }
        
        @Override
        public void run(){
            try {
                CommMessage operationResponse= sendMessage(request).recvResponseFor(request);
                operationMessageResponse.setMessage(operationResponse.value());
                writeResponseOnExchange(operationMessageResponse,operation,exchangeName);
            } catch (IOException ex) {
                Logger.getLogger(ServerJavaService.class.getName()).log(Level.SEVERE, null, ex);
            }
        }
        
        public void configure(String operation,String exchangeName,String splitToken,Channel channel){
            this.operation=operation;
            this.exchangeName=exchangeName;
            this.splitToken=splitToken;
            this.channel=channel;
            
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
    
    
    
    
}
