include "ini_utils.iol"
include "metajolie.iol"
include "dependencies.iol"

execution{concurrent}

type queueRequest: void {
 .message: undefined
 .exchangeName: string
 .routingKey: string
 .token: string
}

type RecRespType:void{
.token: string
.message: undefined
}

cset{
token:RecRespType.token
}

interface ServerRequest{
RequestResponse: request
OneWay: test
OneWay: prova
OneWay: operation
}

interface SecondaInterfaccia{
RequestResponse: requestDue
}

interface embeddedQueue{
OneWay: writeOnExchange(queueRequest)
OneWay:configure(undefined)
}

interface CallbackInterface{
OneWay:_receiveResponse(RecRespType)
}

inputPort Server{
Location:"local"
Interfaces: ServerRequest,SecondaInterfaccia,CallbackInterface
}

outputPort Queue{
Interfaces: embeddedQueue
}

embedded {
Java: "org.jolielang.rabbitmqclient.ClientJavaService" in Queue
}

init{
iniRequest="./RabbitMQTool/RabbitMqClient.ini";
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
request.portData<<outputPortData;
request.hostname=JDEP_RABBITMQ_LOCATION;
request.responseApiType=iniResponse.automatizationParameter.get_response_api_type;
request.maxThread=iniResponse.automatizationParameter.max_thread;
request.millisPullRange=iniResponse.automatizationParameter.millis_pull_range;
configure@Queue(request)
}
main
{

[request(requestClientRequest)(requestServerResponse){
requestRequest.message<<requestClientRequest;
requestRequest.exchangeName="socket://localhost:9000";
requestRequest.routingKey="socket://localhost:9000#request";
csets.token=new;
requestRequest.token=csets.token;
writeOnExchange@Queue(requestRequest);
_receiveResponse(requestRes);
requestServerResponse<<requestRes.message
}]

[test(testResponse)]{
testRequest.message<<testResponse;
testRequest.exchangeName="socket://localhost:9000";
testRequest.routingKey="socket://localhost:9000#test";
testRequest.token="";
writeOnExchange@Queue(testRequest)
}

[prova(provaResponse)]{
provaRequest.message<<provaResponse;
provaRequest.exchangeName="socket://localhost:9000";
provaRequest.routingKey="socket://localhost:9000#prova";
provaRequest.token="";
writeOnExchange@Queue(provaRequest)
}

[operation(operationResponse)]{
operationRequest.message<<operationResponse;
operationRequest.exchangeName="socket://localhost:9000";
operationRequest.routingKey="socket://localhost:9000#operation";
operationRequest.token="";
writeOnExchange@Queue(operationRequest)
}

[requestDue(requestDueClientRequest)(requestDueServerResponse){
requestDueRequest.message<<requestDueClientRequest;
requestDueRequest.exchangeName="socket://localhost:9000";
requestDueRequest.routingKey="socket://localhost:9000#requestDue";
csets.token=new;
requestDueRequest.token=csets.token;
writeOnExchange@Queue(requestDueRequest);
_receiveResponse(requestDueRes);
requestDueServerResponse<<requestDueRes.message
}]

}
