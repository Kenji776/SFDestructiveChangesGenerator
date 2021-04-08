var ignoreDeployErrors = true;       //allows deployment to continue even if some items fail.
var checkOnlyMode = true; //will only validate that the deployment will succeed but not do it if true.
var openDeployPageOnComplete = true; //open a web browser tab to the deployment status screen after each deploy.
var usernames = ['someUser@org1.com','someUser@org2.com']; //list of usernames configured in this sfdx project that you want to build and deploy for.

//don't change these unless you have a good reason to.
var apexScriptFile = 'buildPackage.apex';
var apexResultFile = 'executeResult.txt';
var outputPackageFile = 'destructiveChanges.xml';
var packageFolder = 'destructiveChanges';



var resultsObject;
const fs = require('fs');
const path = require('path')
const { exec } = require("child_process");

function init()
{
	log('                                    Destructive Package Builder/Deployer 1.0!\r\n',true,'green');
	log('Processing for usernames: ' + usernames);
	var d = new Date();
	d.toLocaleString();  
	
	log('Started process at ' + d, false);
	
	mainLoop(0);
}

function mainLoop(index)
{
	if(index>0) log('\n\nProcessing next org');
	username = usernames[index];
	
	log('Hang on getting some stuff together for ' + username +'.....',true);
	runCommand('sfdx force:org:display --json -u ' +username,function(error, stdout, stderr){
		resultsObject = JSON.parse(stdout);
		log('Generating destructive changes for \x1b[33m' + username + '\x1b[0m org alias \x1b[33m' + resultsObject.result.alias + '\x1b[0m \r\n');
	
		buildPackage(apexScriptFile,apexResultFile, username, function(error, stdout, stderr){
			log('Apex Script Ran',true,'green');

			var content = fs.readFileSync(apexResultFile);
			
			log('Got File Content',true,'green');
			
			writePackageXML();
			
			var packagePayloadXML = readXMLFromApexResult(content.toString());

			log('Extracted Package XML',true,'green');
			
			writePackagePayload(outputPackageFile,packagePayloadXML);	

			log('Package XML Written to file',true,'green');		
			
			if(packagePayloadXML.indexOf('<name>') == -1)
			{
				log('Nothing found to destroy',true,'green');
				if(index<usernames.length-1) mainLoop(index+1)
				else finish();
			}
			else
			{
				log('Deploying changes...',true,'green');
				
				deployPackage(username, function(error, stdout, stderr){
					deployResult = JSON.parse(stdout);
					log(deployResult,false);
					
					if(error || stderr || !deployResult.result.success)
					{
						log('----------------------- DEPLOYMENT ERROR! --------------------------',true,'red');
						if(error) log(JSON.stringify(error, null, 2),true,'red');
						if(stderr) log(JSON.stringify(stderr, null, 2),true,'red');
						log(JSON.stringify(deployResult.result, null, 2));
					}
					else
					{
						log('DEPLOYMENT SUCCESS!',true,'green');						
					}
					for(prop in deployResult.result)
					{
						if(deployResult.hasOwnProperty(prop))
						{
							log(prop + ': ' + deployResult[prop]);
							log(deployResult.result,false);
						}
					}						
					
					if(openDeployPageOnComplete)
					{
						runCommand('start ' + resultsObject.result.instanceUrl+'/lightning/setup/DeployStatus/home');
					}
					
					if(index<usernames.length-1) mainLoop(index+1)
					else finish();
				});
			}
			
		});
	});	
}

function finish()
{
	log('Process completed',true,'yellow');
	log('\r\n\r\n------------------------------------------------ ', false);
	process.exit(1);	
}

function buildPackage(inputFile,outputFile,username,callback)
{
	runCommand('sfdx force:apex:execute -f '+inputFile+' -u '+username+ '>'+outputFile, function(error, stdout, stderr){
		callback(error, stdout, stderr);
	});
}

function readXMLFromApexResult(content)
{
	
	var xmlData = content.split('[packageScript]').pop().split('[/packageScript]')[0];

	return xmlData;
}

function writePackageXML()
{
	var packageXML = '<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"><version>48.0</version></Package>';
	if (!fs.existsSync(packageFolder)){
		fs.mkdirSync(packageFolder);
	}

	if (!fs.existsSync(packageFolder+'\\'+resultsObject.result.alias)){
		fs.mkdirSync(packageFolder+'\\'+resultsObject.result.alias);
	}
	
	fs.writeFileSync(packageFolder+'\\'+resultsObject.result.alias+'\\package.xml', packageXML, function(err)
	{
		if(err) 
		{
			return log(err);
		}
		log("Package.xml created.");
	}); 		
}
function writePackagePayload(filename, content)
{
	if (!fs.existsSync(packageFolder)){
		fs.mkdirSync(packageFolder);
	}

	if (!fs.existsSync(packageFolder+'\\'+resultsObject.result.alias)){
		fs.mkdirSync(packageFolder+'\\'+resultsObject.result.alias);
	}
	
	fs.writeFileSync(packageFolder+'\\'+resultsObject.result.alias+'\\'+filename, content, function(err)
	{
		if(err) 
		{
			return log(err);
		}
		log("destructiveChanges.xml created");
	}); 		
}

function deployPackage(username,callback)
{
	var checkFlag = '';
	if(checkOnlyMode) checkFlag = '-c';
	
	var ignoreErrorFlag = ''
	if(ignoreDeployErrors) ignoreErrorFlag = '-o';
	
	runCommand('sfdx force:mdapi:deploy -d "destructiveChanges\\'+resultsObject.result.alias+'" -u '+username+' -w -1 --verbose --json '+checkFlag+ ' ' +ignoreErrorFlag, function(error, stdout, stderr){
		callback(error, stdout, stderr);
	});
}

function runCommand(command,callback)
{
	exec(command, (error, stdout, stderr) => {
		if (error) 
		{
			log('error: ' + error.message,true,'red');
		}
		if (stderr) 
		{
			//this command throws an error even though its working. probably because its like activly processing or something.
			if(!command.startsWith('sfdx force:mdapi:deploy')) log('stderr: ' + stderr,true,'red');
		}
		if(callback) callback(error, stdout, stderr);
	});	
}

function log(logItem,printToScreen,color)
{
	printToScreen = printToScreen != null ? printToScreen : true;
	var colorCode='';
	switch(color) {
		case 'red':
			colorCode='\x1b[31m'
		break;
		case 'green':
			colorCode='\x1b[32m';
		break;
		case 'yellow':
			colorCode='\x1b[33m';
	}
	
	if(printToScreen) console.log(colorCode+''+logItem+'\x1b[0m');
	
	fs.appendFile('log.txt', logItem + '\r\n', function (err) {
		if (err) throw err;
	});	
	
	
}
process.on('uncaughtException', (err) => {
    log(err,true,'red');
    process.exit(1) //mandatory (as per the Node docs)
})

init();

