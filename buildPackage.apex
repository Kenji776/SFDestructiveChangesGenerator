/******************************************************************
* @Name Dynamic destructive changes metadata builder
* @Author Skience / Daniel Llewellyn (Kenji776@gmail.com)
* @Date 5/31/2020
* @Description This is an execute anonymous script meant to be run on the local machine within a sfdx project folder. It is a utility class to help you generate a destructiveChanges.xml file that can be deployed
*              to your org. This is useful for cases when you don't know ahead of time exactly what items you want to delete but could deduce through apex logic. Such as in the case where you only want to keep a few specific 
*              list views for an object but don't know which ones may have been created (as in the sample code that comes with this script). So you write some logic to query for the layouts, exclude the ones you want to keep
*              feed the rest into the sObjectsListToStringList method, and then feed the results of that into the buildPackageString method. It will then print out the xml required for the file which you can save into
*              a destructiveChanges.xml file. Or using the included script it can be automatically extracted and deployed (see build_and_deploy_changes.js) 
*
* @Limitations Currently this script is only useful for building destructive changes for objects that support querying through apex. In the future I hope to incorperate the Apex metadata wrapper from
               https://github.com/financialforcedev/apex-mdapi to allow querying any metadata type for much more flexibility.
********************************************************************/ 

/**
* @Description main entry point of script. Calling this will trigger the building of the destructiveChanges file.
**/
public static string buildPackage()
{
	system.debug('\n\n\n------ Building package for org ID: ' + UserInfo.getOrganizationId());
	
    map<string,list<string>> packageContents = new map<string,list<string>>();
    
	//sample of deleting all list views for lead, account and opportunity except for those defined in the reservedListViews function
    packageContents.put('ListView',  getListViews(reservedListViews()));
    
	//Add more to your package contents here. The key is the MetaData name of the object, and the value is a list of elements of that type to delete.
    string packageBody = buildPackageString(packageContents);

    return packageBody;
}

/**
* @Description creates the map of list of objects and views to not delete
* @return map of sObject names to list of views not to delete
**/
public static map<string,list<string>> reservedListViews()
{
	return new Map<String,list<string>> {
		'Lead'        => new list<string> { 'Open_Referrals_Im_Assigned','RecentlyViewedLeads' },
		'Account'     => new list<string> { 'MyAccounts','RecentlyViewedAccounts' },
		'Opportunity' => new list<string> { 'MyOpportunities','My_Closed_Opportunities','RecentlyViewedOpportunities' }
	};
}

/**
* @Description method for getting any listView metadata entries we want to delete.
* @Param objectToExcludedViewsMap a map of sObject name to a list of views NOT to delete. 
* @Return a map of sObject names to a list of views with the entries from objectToExcludedViewsMap excluded.
**/
public static list<string> getListViews(map<string,list<string>> objectToExcludedViewsMap)
{
	map<string,list<string>> destructivePackage = new map<string,list<string>>();
	map<string,list<listview>> viewsToRemove = new map<string,list<listview>>();
	
	//iterate over the map of object names to list views and get all their list views and add them to the list of views to delete.
	for(string objectName : objectToExcludedViewsMap.keySet())
	{
		list<string> viewsToSave = objectToExcludedViewsMap.get(objectName) != null ? objectToExcludedViewsMap.get(objectName) : new list<string>();
		system.debug('Getting list views for ' + objectName);
		system.debug(getListviews(objectName, viewsToSave));
		viewsToRemove.put(objectName, getListviews(objectName, viewsToSave));
	}
	
	//format the list of views to delete in proper package.xml format
	list<string> viewNames = sObjectListToStringList(viewsToRemove,'developername',true,true);
	
	return viewNames;
}

/**
* @Description Takes a list of sObjects and returns a list of formatted strings that can be used as the <member> section of a destructiveChanges xml file. Examle, given a list of listviews and passing in developername as
*              the propertyName and true for includeObjectPrefix and true for includeNamespace you'd get back an entry that might look like "FinServ__FinancialAccount.MyPackage__myView" where FinServe__FinancialAccount
*              was the type of sObject the list view pertained to, MyPackage was the namespace and myView was the developerName of the list view itself. This method only really works for metadata types that can be 
*              queried in Apex such as page payouts, listviews, etc.
* @Param object a list of sObjects to process to build strings that can be used as <member> properties for the XML file.
* @Param propertyName the name of the field on the sObject which to use as the primary part of the identifier. Usually this will be developerName or possibly name (as in the case for page layouts)
* @Param includeObjectPrefix boolean of whether or not to include the name of the sObject type in the return string. For example since list views are grouped together in one section in the destructiveChanges xml, you do need the 
*                            prefix so the destructiveChanges.xml knows what object a member applies to. In most cases this will be true.
* @Param includeNamespace include the namespace of custom components. This will usually be true.
* @Return a list of strings that can be used as <member> entries in the destructiveChanges.xml file.
**/
public static list<string> sObjectListToStringList(map<string,list<sObject>> objects, string propertyName, boolean includeObjectPrefix, boolean includeNamespace)
{
	list<string> items = new list<string>();
	for(string thisType : objects.keySet())
	{
		 
		string prefix = includeObjectPrefix ? thisType+'.' : '';
		
		for(sObject thisObject : objects.get(thisType))
		{
			string namespace = includeNamespace && thisObject.get('NamespacePrefix') != null ? thisObject.get('NamespacePrefix')+'__' : '';
			items.add(prefix + namespace + (string) thisObject.get(propertyName));
		}
	}
	return items;
}

/**
* @Description gets all the list views for a given object that are not in the list of views to exclude.
* @param objectName the name of the sObject you want to retrieve list views for.
* @param viewsToExclude an optional list of views to exclude from the query.
**/
public static list<listview> getListviews(string objectName, list<string> viewsToExclude)
{
	viewsToExclude = viewsToExclude != null ? viewsToExclude : new list<string>();
	return [select id, developername, NamespacePrefix, sobjectType from listview where sObjectType = :objectName and developername not in :viewsToExclude and developerName !='test'];
}

/**
* @Description given a map of type names to members this method will format them as a destructiveChanges.xml file. This data can then be output and used to create destructiveChanges.xml files.
*              The start and end tag values are to allow the node.js script to extract the contents of the generated file since as far as I am aware locally run apex script cannot generate files so we simply
*              extract the results from the log using those values as markers where the actual values start and stop.
* @param packageData a map of type names to their members. Type names are metadata category types, such as ApexClass, Layout, CustomField, etc. 
* @return string string that can be used as a destructiveChanges.xml file for destructive changes.
**/
public static string buildPackageString(map<string,list<string>> packageData)
{
    string startTagVal = 'packageScript';
	string endTagVal = '/packageScript';
    
	string packageBody = '['+startTagVal+']<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">\r\n<version>48</version>\r\n<types>\r\n';

	for(string thisItemType : packageData.keySet())
	{
		list<string> members = packageData.get(thisItemType);
		if(members.isEmpty()) continue;
		packageBody += '    <name>'+thisItemType+'</name>\r\n';
		for(string thisMember : members)
		{
			packageBody += '    <members>'+thisMember+'</members>\r\n';
		}
	}
	packageBody += '</types>\r\n</Package>['+endTagVal+']';
	
	return packageBody;
}

system.debug(buildPackage());