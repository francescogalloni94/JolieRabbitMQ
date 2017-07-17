include "ini_utils.iol"
include "metajolie.iol"
include "dependencies.iol"

type configureRequest: void{
.apiType : string
.maxThread : int
.millisPullRange: long
.portMetaData : Participant
.hostName: string
}

interface EmbeddedRabbit{
OneWay: configure(configureRequest)
}

inputPort ServerLocal {
Location:"local"
Interfaces: ServerInterface,SecondaInterfaccia
}

outputPort RabbitMq {
Interfaces: EmbeddedRabbit
}

embedded {
Java: "org.jolielang.rabbitmqserver.ServerJavaService" in RabbitMq
}

init{
iniRequest="./RabbitMQTool/RabbitMqServer.ini";
parseIniFile@IniUtils(iniRequest)(iniResponse);
portRequest.name.name=iniResponse.fileParameter.port_name;
portRequest.filename=iniResponse.fileParameter.file_name;
getInputPortMetaData@MetaJolie(portRequest)(res);
for(i=0,i<#res.input,i++){
if(res.input[i].name.name==portRequest.name.name){
var<<res.input[i]
}
};
config.portMetaData<<var;
config.apiType=iniResponse.automatizationParameter.api_type;
config.maxThread=int(iniResponse.automatizationParameter.max_thread);
config.millisPullRange=long(iniResponse.automatizationParameter.millis_pull_range);
config.hostName=JDEP_RABBITMQ_LOCATION;
configure@RabbitMq(config)
}

