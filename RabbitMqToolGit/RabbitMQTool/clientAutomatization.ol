include "console.iol"
include "metajolie.iol"
include "string_utils.iol"
include "file.iol"
include "ini_utils.iol"

main
{
  
iniRequest="RabbitMqClient.ini";
parseIniFile@IniUtils(iniRequest)(iniResponse);
request.name.name=iniResponse.fileParameter.port_name;
request.filename=iniResponse.fileParameter.file_name;
getMetaData@MetaJolie(request)(var);
outputPortData=request.name.name;

  for(i=0,i<#var.output,i++){
     if(var.output[i].name.name==outputPortData){
       outputPortData.location=var.output[i].location;
       for(j=0,j<#var.output[i].interfaces,j++){
       		outputPortData.interfaces[j].name=var.output[i].interfaces[j].name.name;
       		for(k=0,k<#var.interfaces,k++){
       			if(var.interfaces[k].name.name==var.output[i].interfaces[j].name.name){
       				outputPortData.interfaces[j]<<var.interfaces[k]
       			}
       		}
       }

     }
  };

  
  

  fileOL="include \"ini_utils.iol\"\n"
      +"include \"metajolie.iol\"\n"
      +"include \"dependencies.iol\"\n\n"
      +"execution{concurrent}\n\n"
  		+"type queueRequest: void {\n"
  		+" .message: undefined\n"
  		+" .exchangeName: string\n"
  		+" .routingKey: string\n"
      +" .token: string\n"
      +"}\n\n";

  fileOL+="type RecRespType:void{\n"
        +".token: string\n"
        +".message: undefined\n"
        +"}\n\n";

  fileOL+="cset{\n"
        +"token:RecRespType.token\n"
        +"}\n\n";

  		for(j=0,j<#outputPortData.interfaces,j++){
  		  fileOL+="interface "+outputPortData.interfaces[j].name.name+"{\n";
  		for(i=0,i<#outputPortData.interfaces[j].operations,i++){
        if(outputPortData.interfaces[j].operations[i].output.name==null){
  			fileOL+="OneWay: "+outputPortData.interfaces[j].operations[i].operation_name+"\n"
      }else{
        fileOL+="RequestResponse: "+outputPortData.interfaces[j].operations[i].operation_name+"\n"
      }
  		};
  		fileOL+="}\n\n"
  	};
  	fileOL+="interface embeddedQueue{\n"
  			+"OneWay: writeOnExchange(queueRequest)\n"
        +"OneWay:configure(undefined)\n"
  			+"}\n\n";

    fileOL+="interface CallbackInterface{\n"
            +"OneWay:_receiveResponse(RecRespType)\n"
            +"}\n\n";

  	fileOL+="inputPort Server{\n"
  	       +"Location:\"local\"\n"
  	       +"Interfaces: "; 
  	       for(i=0,i<#outputPortData.interfaces,i++){
  	       		if(i==(#outputPortData.interfaces-1)){
  	       			fileOL+=outputPortData.interfaces[i].name.name
  	       		}else{
  	       			fileOL+=outputPortData.interfaces[i].name.name+","
  	       		}
  	       };
           fileOL+=",CallbackInterface";
  	       fileOL+="\n}\n\n";
   
    fileOL+="outputPort Queue{\n"
    		+"Interfaces: embeddedQueue\n"
    		+"}\n\n";

    fileOL+="embedded {\n"
    		+"Java: \"org.jolielang.rabbitmqclient.ClientJavaService\" in Queue\n"
    		+"}\n\n";

     fileOL+="init{\n"
            +"iniRequest=\"./RabbitMQTool/RabbitMqClient.ini\";\n"
            +"parseIniFile@IniUtils(iniRequest)(iniResponse);\n"
            +"request.name.name=iniResponse.fileParameter.port_name;\n"
            +"request.filename=iniResponse.fileParameter.file_name;\n"
            +"getMetaData@MetaJolie(request)(var);\n"
            +"outputPortData=request.name.name;\n"
            +"for(i=0,i<#var.output,i++){\n"
            +"if(var.output[i].name.name==outputPortData){\n"
            +"outputPortData.location=var.output[i].location;\n"
            +"for(j=0,j<#var.output[i].interfaces,j++){\n"
            +"outputPortData.interfaces[j].name=var.output[i].interfaces[j].name.name;\n"
            +"for(k=0,k<#var.interfaces,k++){\n"
            +"if(var.interfaces[k].name.name==var.output[i].interfaces[j].name.name){\n"
            +"outputPortData.interfaces[j]<<var.interfaces[k]\n"
            +"}\n"
            +"}\n"
            +"}\n"
            +"}\n"
            +"};\n"
            +"request.portData<<outputPortData;\n"
            +"request.hostname=JDEP_RABBITMQ_LOCATION;\n"
            +"request.responseApiType=iniResponse.automatizationParameter.get_response_api_type;\n"
            +"request.maxThread=iniResponse.automatizationParameter.max_thread;\n"
            +"request.millisPullRange=iniResponse.automatizationParameter.millis_pull_range;\n"
            +"configure@Queue(request)\n"
            +"}\n";


    fileOL+="main\n"
    		+"{\n\n";
    		for(i=0,i<#outputPortData.interfaces,i++){
    			for(j=0,j<#outputPortData.interfaces[i].operations,j++){
            if(outputPortData.interfaces[i].operations[j].output.name==null){
    				fileOL+="["+outputPortData.interfaces[i].operations[j].operation_name+"("+outputPortData.interfaces[i].operations[j].operation_name+"Response)]{\n"
    						+outputPortData.interfaces[i].operations[j].operation_name+"Request.message<<"+outputPortData.interfaces[i].operations[j].operation_name+"Response;\n"
    						+outputPortData.interfaces[i].operations[j].operation_name+"Request.exchangeName=\""+outputPortData.location+"\";\n"
    						+outputPortData.interfaces[i].operations[j].operation_name+"Request.routingKey=\""+outputPortData.location+"#"+outputPortData.interfaces[i].operations[j].operation_name+"\";\n"
                +outputPortData.interfaces[i].operations[j].operation_name+"Request.token=\"\";\n"
                +"writeOnExchange@Queue("+outputPortData.interfaces[i].operations[j].operation_name+"Request)\n"
    						+"}\n\n"
    			}else{
            fileOL+="["+outputPortData.interfaces[i].operations[j].operation_name+"("+outputPortData.interfaces[i].operations[j].operation_name+"ClientRequest)("+outputPortData.interfaces[i].operations[j].operation_name+"ServerResponse){\n"
                    +outputPortData.interfaces[i].operations[j].operation_name+"Request.message<<"+outputPortData.interfaces[i].operations[j].operation_name+"ClientRequest;\n"
                    +outputPortData.interfaces[i].operations[j].operation_name+"Request.exchangeName=\""+outputPortData.location+"\";\n"
                    +outputPortData.interfaces[i].operations[j].operation_name+"Request.routingKey=\""+outputPortData.location+"#"+outputPortData.interfaces[i].operations[j].operation_name+"\";\n"
                    +"csets.token=new;\n"
                    +outputPortData.interfaces[i].operations[j].operation_name+"Request.token=csets.token;\n"
                    +"writeOnExchange@Queue("+outputPortData.interfaces[i].operations[j].operation_name+"Request);\n"
                    +"_receiveResponse("+outputPortData.interfaces[i].operations[j].operation_name+"Res);\n"
                    +outputPortData.interfaces[i].operations[j].operation_name+"ServerResponse<<"+outputPortData.interfaces[i].operations[j].operation_name+"Res.message"
                    +"\n}]\n\n"
          }
        }
    		};

    fileOL+="}\n";





   fileRequest.content=fileOL;
   fileRequest.filename="ClientQueueConfigure.ol";
   writeFile@File(fileRequest)();
   readFile.filename=iniResponse.fileParameter.file_name;
   readFile@File(readFile)(file);
   splitRequest=file;
   splitRequest.regex="main\\s*\\{";
   split@StringUtils(splitRequest)(splitResponse);
   newFile.content=splitResponse.result[0]
   +"/* Begin @ DynamicQueueArchitecture */\n"
   +"embedded {\n Jolie: \"./RabbitMQTool/ClientQueueConfigure.ol\" in "+outputPortData+"\n}\n"
   +"/* End @ DynamicQueueArchitecture */\n\n"
   +"main{\n\n"
   +splitResponse.result[1];
   newFile.filename=iniResponse.fileParameter.file_name;
   writeFile@File(newFile)()





}