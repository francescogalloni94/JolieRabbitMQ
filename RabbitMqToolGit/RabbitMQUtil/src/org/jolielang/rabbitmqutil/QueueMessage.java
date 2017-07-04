/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package org.jolielang.rabbitmqutil;

import java.io.Serializable;
import jolie.runtime.Value;


public class QueueMessage implements Serializable {
    
    private String id="";
    private Value message;
    private String sessionToken="";
    
    public QueueMessage(String id,Value message,String sessionToken){
        this.id=id;
        this.message=message;
        this.sessionToken=sessionToken;
    }
    
    public QueueMessage(){
        
    }
    
    public String getId(){
        return id;
    }
    
    public Value getMessage(){
        return message;
    }
    
    public void setId(String id){
        this.id=id;
    }
    
    public void setMessage(Value message){
        this.message=message;
    }
    
    public String getSessionToken(){
        return sessionToken;
    }
    
    public void setSessionToken(String sessionToken){
        this.sessionToken=sessionToken;
    }
    
}
