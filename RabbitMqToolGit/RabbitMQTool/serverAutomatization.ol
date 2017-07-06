include "console.iol"
include "metaJolie.iol"
include "string_utils.iol"
include "file.iol"
include "ini_utils.iol"

main{
      
      iniRequest="RabbitMqServer.ini";
      parseIniFile@IniUtils(iniRequest)(iniResponse);
      portRequest.name.name=iniResponse.fileParameter.port_name;
      portRequest.filename=iniResponse.fileParameter.file_name;
      getInputPortMetaData@MetaJolie(portRequest)(res);
      inputPortData=portRequest.name.name;
      for(i=0,i<#res.input,i++){
      	if(res.input[i].name.name==inputPortData){
      		for(j=0,j<#res.input[i].interfaces,j++){
      			inputPortData.interfaces[j].name=res.input[i].interfaces[j].name.name
      		}
      	}
      };
       
       
      //valueToPrettyString@StringUtils(inputPortData)(val);
      //print@Console(val)();


      fileOL="include \"ini_utils.iol\"\n\n"
                  +"type configureRequest: void{\n"
      		+".apiType : string\n"
      		+".maxThread : int\n"
      		+".millisPullRange: long\n"
      		+".portMetaData : Participant\n"
      		+".hostName: string\n"
      		+"}\n\n"
      		+"interface EmbeddedRabbit{\n"
      		+"OneWay: configure(configureRequest)\n"
      		+"}\n\n"
      		+"inputPort ServerLocal {\n"
      		+"Location:\"local\"\n"
      		+"Interfaces: ";
      		for(i=0,i<#inputPortData.interfaces,i++){
      			if(i==(#inputPortData.interfaces-1)){
      				fileOL+=inputPortData.interfaces[i].name+"\n"
      			}else{
      				fileOL+=inputPortData.interfaces[i].name+","
      			}
      		};
       fileOL+="}\n\n";
       fileOL+="outputPort RabbitMq {\n"
       			+"Interfaces: EmbeddedRabbit\n"
       			+"}\n\n"
       			+"embedded {\n"
       			+"Java: \"org.jolielang.rabbitmqserver.ServerJavaService\" in RabbitMq\n"
       			+"}\n\n";

       fileOL+="init{\n"
       			+"portRequest.name.name=\""+inputPortData+"\";\n"
       			+"portRequest.filename=\""+portRequest.filename+"\";\n"
       			+"getInputPortMetaData@MetaJolie(portRequest)(res);\n"
       			+"for(i=0,i<#res.input,i++){\n"
       			+"if(res.input[i].name.name==portRequest.name.name){\n"
       			+"var<<res.input[i]\n"
       			+"}\n"
       			+"};\n"
                        +"iniRequest=\"./RabbitMQTool/RabbitMqServer.ini\";\n"
                        +"parseIniFile@IniUtils(iniRequest)(iniResponse);\n"
       			+"config.portMetaData<<var;\n"
       			+"config.apiType=iniResponse.automatizationParameter.api_type;\n"
       			+"config.maxThread=int(iniResponse.automatizationParameter.max_thread);\n"
       			+"config.millisPullRange=long(iniResponse.automatizationParameter.millis_pull_range);\n"
       			+"config.hostName=iniResponse.automatizationParameter.rabbitmq_host_name;\n"
       			+"configure@RabbitMq(config)\n"
       			+"}\n\n";











       fileRequest.content=fileOL;
   	 fileRequest.filename="ServerQueueConfigure.ol";
   	 writeFile@File(fileRequest)();
       readFile.filename=iniResponse.fileParameter.file_name;
       readFile@File(readFile)(file);
       splitRequest=file;
       splitRequest.regex="main\\s*\\{";
       split@StringUtils(splitRequest)(splitResponse);
       newFile.content=splitResponse.result[0]
                       +"/* Begin @ DynamicQueueArchitecture */\n"
                       +"include \"./RabbitMQTool/ServerQueueConfigure.ol\"\n"
                       +"/* End @ DynamicQueueArchitecture */\n\n"
                       +"main{\n\n"
                       +splitResponse.result[1];
      newFile.filename=iniResponse.fileParameter.file_name;
      writeFile@File(newFile)()





}