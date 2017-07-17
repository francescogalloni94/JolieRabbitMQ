
include "exec.iol"
include "file.iol"
include "console.iol"
include "string_utils.iol"
include "database.iol"
include "time.iol"
include "InterfaceAPI.iol"
include "ini_utils.iol"


outputPort DockerIn {
	Location: "socket://localhost:8008"
	Protocol: sodep
	Interfaces: InterfaceAPI
}


main
{
	iniRequest="DockerAutomatization.ini";
    parseIniFile@IniUtils(iniRequest)(iniResponse);
    
    rqCnt.name = "rabbitexposecnt";
		rqCnt.Image = "rabbitmq:3";
		rqCnt.ExposedPorts.("5672/tcp") = obj.("{}");
		createContainer@DockerIn( rqCnt )( serverResponse );
		rabbitId.id=serverResponse.Id;

    undef(rqCnt);
	startContainer@DockerIn( rabbitId )( response );
    

    info.filters.id =rabbitId.id;
    containers@DockerIn( info )( container_info );
    serverqueue_host = container_info.container[ 0 ].NetworkSettings.Networks.bridge.IPAddress;
	println@Console("VALLLLLL  "+serverqueue_host)();
    undef( crq );

    file.filename ="RabbitMQTool/dependencies.iol";
	file.content = "constants {\n"
                   +"JDEP_RABBITMQ_LOCATION =\""+serverqueue_host+"\"\n"
				   +"}\n";						

	writeFile@File( file )();
	undef( file );

    if(iniResponse.automatizationParameter.fileLocation=="file"){

    name=new;
	mkdir@File( name )();
	rabbitfolder=name+"/RabbitMQTool";
	libfolder=name+"/lib";
	mkdir@File(rabbitfolder)();
    mkdir@File(libfolder)();
    readFile.filename=iniResponse.automatizationParameter.serverFile;
    readFile@File(readFile)(file);
    fileRequest.content=file;
    fileRequest.filename=name+"/Server.ol";
    writeFile@File(fileRequest)();
	copyDir@File({.to=rabbitfolder, .from="RabbitMQTool"})();
	copyDir@File({.to=libfolder, .from="lib"})();
	undef( file );
	file.filename = name + "/Dockerfile";
	file.content = "FROM jolielang/jolie-docker-deployer\n"
	                +"COPY " + name + "/Server.ol main.ol\n"
	                +"COPY "+name+"/RabbitMQTool RabbitMQTool\n"
	                +"COPY "+name+"/lib lib\n";

	writeFile@File( file )();
	undef( file );
	
	ex_rq = "tar";
	ex_rq.args[ 0 ] = "-cvf";
	ex_rq.args[ 1 ] =name+".tar";
	ex_rq.args[ 2 ] =name;
	ex_rq.waitFor = 1;
	exec@Exec( ex_rq )();

	deleteDir@File( name )();

    print@Console("dopo exec")();
	file.filename =name+".tar";
	file.format = "binary";
	readFile@File( file )( rq.file );
	print@Console("read file")();
	rq.t = "serverqueue:latest";
	rq.dockerfile =name+"/Dockerfile";
	print@Console("build")();
	build@DockerIn( rq )( response );
	print@Console("dopo build")();
	
	undef( rq );
	undef( ex_rq );
    undef( name );





	name=new;
	rabbitfolder=name+"/RabbitMQTool";
	libfolder=name+"/lib";
	mkdir@File( name )();
	mkdir@File(rabbitfolder)();
	mkdir@File(libfolder)();
	undef( readFile );
	readFile.filename=iniResponse.automatizationParameter.clientFile;
    readFile@File(readFile)(file);
    undef( fileRequest );
    fileRequest.content=file;
    fileRequest.filename=name+"/Client.ol";
    writeFile@File(fileRequest)();
    undef( file );
	copyDir@File({.to=rabbitfolder, .from="RabbitMQTool"})();
	copyDir@File({.to=libfolder, .from="lib"})();
	file.filename = name + "/Dockerfile";
	file.content = "FROM jolielang/jolie-docker-deployer\n"
	                +"COPY " + name + "/Client.ol main.ol\n"
	                +"COPY " + name+"/RabbitMQTool RabbitMQTool\n"
	                +"COPY "+name+"/lib lib\n";
	                
	               
	writeFile@File( file )();
	undef( file );
	ex_rq = "tar";
	ex_rq.args[ 0 ] = "-cvf";
	ex_rq.args[ 1 ] =name+".tar";
	ex_rq.args[ 2 ] =name;
	ex_rq.waitFor = 1;
	exec@Exec( ex_rq )();
	deleteDir@File( name )();


    print@Console("dopo exec")();
	file.filename =name+".tar";
	file.format = "binary";
	readFile@File( file )( rq.file );
	print@Console("read file")();
	rq.t = "clientqueue:latest";
	rq.dockerfile =name+"/Dockerfile";
	print@Console("build")();
	build@DockerIn( rq )( response );
	print@Console("dopo build")()
}else if(iniResponse.automatizationParameter.fileLocation=="git") {
    nullProcess
};
    
	rqCnt.name = "serverqueuecnt";
		rqCnt.Image = "serverqueue:latest";
		rqCnt.Env[0]="JDEP_RABBITMQ_LOCATION="+serverqueue_host;
		createContainer@DockerIn( rqCnt )( serverResponse );
		serverqueuecnt.id=serverResponse.Id;

    undef(rqCnt);
    crq.id=serverqueuecnt.id;
	startContainer@DockerIn( crq )( response );
    rqCnt.name="clientqueuecnt";
    rqCnt.Image="clientqueue:latest";
    rqCnt.Env[0] = "JDEP_RABBITMQ_LOCATION="+serverqueue_host;
    createContainer@DockerIn( rqCnt )( clientResponse );
    clientqueuecnt.id=clientResponse.Id;
   
	undef( crq );
	crq.id=clientqueuecnt.id;
	startContainer@DockerIn( crq )( response )










}