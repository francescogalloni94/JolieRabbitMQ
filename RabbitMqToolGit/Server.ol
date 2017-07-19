include "console.iol"
include "string_utils.iol"
include "time.iol"
include "file.iol"

execution{concurrent}



interface ServerInterface{
	OneWay: test(undefined)
	OneWay: prova(undefined)
	OneWay: operation(undefined)
  RequestResponse: request(undefined)(undefined)

}
interface SecondaInterfaccia {
  RequestResponse: requestDue(undefined)(undefined)
}

/*interface SecondaInterfaccia {
  OneWay: testSeconda(undefined)
  OneWay: operationSeconda(undefined)
  OneWay: provaSeconda(undefined)
}

interface TerzaInterfaccia {
  OneWay: testTerza(undefined)
  OneWay: operationTerza(undefined)
  OneWay: provaTerza(undefined)
}*/



inputPort Server {
	Location:"socket://localhost:9000" 
	Protocol: sodep
	Interfaces: ServerInterface,SecondaInterfaccia
}

init{
   getCurrentTimeMillis@Time()(res);
   fileRequest.filename=string (res)+".csv"
}




/* Begin @ DynamicQueueArchitecture */
include "./RabbitMQTool/ServerQueueConfigure.ol"
/* End @ DynamicQueueArchitecture */



main{





   [test(msg)]{
       //print@Console("test    "+msg.text+"..."+msg.number+"..."+msg.id+"\n")()

       getCurrentTimeMillis@Time()(time);
       currentTime=time;
       delay=currentTime-msg.deliveryTime;
       println@Console(msg.deliveryTime)();
       file=msg.deliveryTime+";"+currentTime+";"+delay+"\n";
       fileRequest.content=file;
       fileRequest.append=1;
       //writeFile@File(fileRequest)();
       sleep@Time(500)()

   }




   [prova(msg2)]{
   print@Console("prova    "+msg2.text+"..."+msg2.number+"..."+msg2.id+"\n")()
   }



   [operation(msg3)]{
   print@Console("operation     "+msg3.text+"..."+msg3.number+"..."+msg3.id+"\n")()
   }

   [request(recv)(resp){
     println@Console("TEMPO "+recv.deliveryTime)();
     resp.saluto="ciao"
   }]
   [requestDue(recv2)(resp2){
     println@Console("TEMPO "+recv2.deliveryTime)();
     resp2.saluto="Frase request response"
   }]

   

}