include "console.iol"
include "string_utils.iol"
include "metaJolie.iol"
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

interface SecondaInterfaccia {
  RequestResponse: requestDue(undefined)(undefined)
}

/*interface TerzaInterfaccia {
  OneWay: testTerza(undefined)
  OneWay: operationTerza(undefined)
  OneWay: provaTerza(undefined)
  RequestResponse: requestTre(undefined)(int)
}*/

//include "dependencies.iol"


outputPort Server {
	Location: "socket://localhost:9000"
	Protocol: sodep
	Interfaces: ServerRequest,SecondaInterfaccia
}






main{

     sleep@Time(5000)();
     requestNumber=args[0];
      //requestNumber=20;
    //testRequest.text="Hello world";
    //testRequest.number=23;
    for(i=0,i<requestNumber,i++){
    getCurrentTimeMillis@Time()(time);
    testRequest.deliveryTime=time;
    //println@Console(i)();
    test@Server(testRequest)
    };
    getCurrentTimeMillis@Time()(time);
    testRequest.deliveryTime=time;
    request@Server(testRequest)(res);
    print@Console("PROVAA"+res.saluto)();
    getCurrentTimeMillis@Time()(time);
    testRequest.deliveryTime=time;
    requestDue@Server(testRequest)(res2);
    print@Console("SECONDA"+res2.saluto)();
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