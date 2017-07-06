include "ini_utils.iol"

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
portRequest.name.name="Server";
portRequest.filename="/Users/gallo/Desktop/tirocinio/direct/Server.ol";
getInputPortMetaData@MetaJolie(portRequest)(res);
for(i=0,i<#res.input,i++){
if(res.input[i].name.name==portRequest.name.name){
var<<res.input[i]
}
};
iniRequest="./RabbitMQTool/RabbitMqServer.ini";
parseIniFile@IniUtils(iniRequest)(iniResponse);
config.portMetaData<<var;
config.apiType=iniResponse.automatizationParameter.api_type;
config.maxThread=int(iniResponse.automatizationParameter.max_thread);
config.millisPullRange=long(iniResponse.automatizationParameter.millis_pull_range);
config.hostName=iniResponse.automatizationParameter.rabbitmq_host_name;
configure@RabbitMq(config)
}

