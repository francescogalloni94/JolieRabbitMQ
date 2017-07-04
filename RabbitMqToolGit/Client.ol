include "console.iol"
include "metaJolie.iol"
include "string_utils.iol"
include "time.iol"

type testRequest: void{
  .deliveryTime: long
}



interface ServerRequest {
  OneWay: test(undefined)
  OneWay: operation(undefined)
  OneWay: prova(undefined)
  RequestResponse: request(undefined)(undefined)
}

/*interface SecondaInterfaccia {
  OneWay: testSeconda(undefined)
  OneWay: operationSeconda(undefined)
  OneWay: provaSeconda(undefined)
  RequestResponse: requestDue(undefined)(int)
}

interface TerzaInterfaccia {
  OneWay: testTerza(undefined)
  OneWay: operationTerza(undefined)
  OneWay: provaTerza(undefined)
  RequestResponse: requestTre(undefined)(int)
}*/


outputPort Server {
	Location: "socket://localhost:9000"
	Protocol: sodep
	Interfaces: ServerRequest
}


embedded {
  Jolie: "./RabbitMQTool/ClientQueueConfigure.ol" in Server
}



main
{
     sleep@Time(5000)();
     requestNumber=args[0];
      //requestNumber=20;
    //testRequest.text="Hello world";
    //testRequest.number=23;
    for(i=0,i<requestNumber,i++){
    getCurrentTimeMillis@Time()(time);
    testRequest.deliveryTime=time;
    println@Console(i)();
    request@Server(testRequest)(res)
    
    //test@Server(testRequest)
    };
    print@Console("PROVAA"+res.saluto)();
    sleep@Time(80000)()
    /*testRequest.text="Hello world";
    testRequest.number=23;
    testRequest.id=50;
    test@QueueConfig(testRequest);
    operationRequest.text="Hello world";
    operationRequest.number=23;
    operationRequest.id=50;
    operation@QueueConfig(operationRequest);
    provaRequest.text="Hello world";
    provaRequest.number=23;
    provaRequest.id=50;
    prova@QueueConfig(provaRequest)*/
}