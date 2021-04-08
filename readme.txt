What is this thing?

This is an application that will help generate destructive package.xml files by running logic against your org to find items to delete for things that you may not support wild card deletes or you
don't know the exact names of the things. Such as in the case where you only want to keep a few specific list views for an object but don't know which ones may have been created by tweaking the 
buildpackage.apex you can automatically build and deploy your changes to an org.

What's required?
Node.Js must be installed on your local machine.
This script must be running inside a folder configured as an sfdx project with visual studio code (it uses SFDX commands for deployment)

How does it work?

The overall process goes like this:

1) Change the buildPackage.apex class to include logic to include the entries you want in your destructive changes. You'll have to write methods to query whatever metadata you want and then using the
sObjectListToStringList method (probably) format your data into a map of type names (string) to a list of members (list<string>) and pass it to the buildPackageString method. Print the results of that
call to the console. An example of doing this is included in the script you can just modify that. The crucial part here is that the script uses a system.debug statment to print the contents of generated
XML. That is because the next step reads from that log.

2) Modify the variables at the top of the build_and_deploy_changes.js, these include

ignoreDeployErrors (boolean)      
--allows deployment to continue even if some items fail.

doDeploy (boolean)
-- controls if any deployment (validate only or actual deploy) happens, or if the XML files are generated and thats it.

checkOnlyMode (boolean)           
--will only validate that the deployment will succeed but not do it if true.

openDeployPageOnComplete (boolean)
--open a web browser tab to the deployment status screen after each deploy.

usernames (javascript array)
--list of usernames configured in this sfdx project that you want to build and deploy for. Format is ['name1','name2','name3'];

That's it now you are ready to run. If on windows you can simply click run the "build and deploy.bat" file. Otherwise simply use node to run "build_and_deploy_changes.js". For each username defined the program will run the apex script, which will generate a log that prints out the generated XML to executeResult.txt (by default). Then the build_and_deploy_changes.js file will extract that text and use it to create a destructiveChanges.xml file. For each org it will create a folder within the destructiveChanges folder and also create the empty package.xml file. It will then use the sfdx force:mdapi:deploy command to deploy the changes (using the ignoreDeployErrors and checkOnlyMode flags you set). It will print the results to the console and also create a log.txt file you can review. Thats it! 