public with sharing class ChangeRequestService {
	
	
	public static void test(){
		System.debug(groupChangeRequests([Select Id, Name From Change_Request__c]));
	}
	
	public static void test2(){
		deployChangeRequests([select id from Change_Request__c WHERE Id='a012800000JapNx'],[
			Select Id, 
				Source_org__r.Username__c,
				Source_org__r.Password__c,
				Source_org__r.Type__c,
				Target_org__r.Username__c,
				Target_org__r.Password__c,
				Target_org__r.Type__c
			From Connection__c WHERE Id='a042800000BRj6v' 
		][0],false,'','Default');
	}
	
	public static String deployChangeRequests(List<Change_Request__c> changeRequests,
					Connection__c connection,
					Boolean isValidate,String testClasses,String testOptions){
		Deployment theDeployment = new Deployment();
		theDeployment.packageXML = new PackageXMLBuilder().getXML(changeRequests,connection);
		theDeployment.sourceOrg = connection.source_org__r;
		theDeployment.targetOrg = connection.target_org__r;
		String testClassesToBeExecuted = '';
		List<String> tests = new List<String>();
		if(testClasses != null && testClasses != 'null'){
			for(String testClass : testClasses.split(',')){
				tests.add(testClass.trim());
			}  
		}
		theDeployment.testClassesToBeExecuted = String.join(tests,';');  
		theDeployment.testOptions = testOptions;
		theDeployment.isValidate = isValidate; 
		HttpRequest req = new HttpRequest();
		req.setTimeout(1000*120);
	    req.setEndpoint('https://kmforce4.herokuapp.com/DeployCode');
	    req.setMethod('POST');
        System.debug(JSON.serializePretty(theDeployment));
	 	req.setBody(JSON.serialize(theDeployment));
	    Http http = new Http();
	    HTTPResponse res = http.send(req);
	    System.debug(res.getBody());	
	    return res.getBody();					
	}
	
	
    
    public static List<GroupElement> groupChangeRequests(List<Change_Request__c> changeRequests){
    	Map<Id,Change_Request__c> changeRequestMap = new Map<Id,Change_Request__c>();
    	Map<String,List<String>> groupVsCommonComponents = new Map<String,List<String>>();
    	for(Change_Request__c cr : changeRequests){
    		changeRequestMap.put(cr.Id,cr);
    	}
    	Map<String,List<Change_Request__c>> groupVsChangeRequestList = new Map<String,List<Change_Request__c>>();
    	Map<Id,Set<String>> changeRequestVsComponents = new Map<Id,Set<String>>();
    	for(Change_Request__c cr: changeRequests){
    	    changeRequestVsComponents.put(cr.Id,new Set<String>());
    	}
    	for(Component__c component : [Select Component_Name__c, Change_Request__c From Component__c 
    										WHERE Change_Request__c in :changeRequests
    										AND Type__c in ('ApexClass','ApexComponent','ApexTrigger','ApexPage','StaticResource')]){
    		if(changeRequestVsComponents.get(component.Change_Request__c)==null){
    			changeRequestVsComponents.put(component.Change_Request__c,new Set<String>());
    		}
    		if(component.Component_Name__c != null ){
	    		changeRequestVsComponents.get(component.Change_Request__c).add(component.Component_Name__c.toLowerCase());
    		}
    	} 
    	
    	Integer index = 0;
    	for(Id changeRequest : changeRequestVsComponents.keySet()){
			List<String> commonWithGroups = new List<String>();
    		for(String groupName : groupVsChangeRequestList.keySet()){
    			for(Change_Request__c  existingCR : groupVsChangeRequestList.get(groupName)){
    				  //checking if the components for current changeRequest is part of existing CRs
    				  if(hasCommonComponents(changeRequestVsComponents.get(changeRequest),changeRequestVsComponents.get(existingCR.Id))){
	    				  	commonWithGroups.add(groupName);
	    				  	break;
    				  }
    			}    			
    		}
    		if(commonWithGroups.size()==0){//if there is not common changes
    			index++;
    			groupVsChangeRequestList.put(''+index,new List<Change_Request__c>{changeRequestMap.get(changeRequest)});    			
    		}else if(commonWithGroups.size()==1){ //add change requst to the already exsting change set
    			groupVsChangeRequestList.get(commonWithGroups[0]).add(changeRequestMap.get(changeRequest));    			
    		}else if(commonWithGroups.size()>1){//cosolidate allGroups into one group since there are common changes with more than one group
    			index++;
    			List<Change_Request__c> newGroupChanges = new List<Change_Request__c>();
    			newGroupChanges.add(changeRequestMap.get(changeRequest));
    			for(String groupName : commonWithGroups){
    				newGroupChanges.addAll(groupVsChangeRequestList.get(groupName));
    				groupVsChangeRequestList.put(groupName,new List<Change_Request__c>());
    			}
    			groupVsChangeRequestList.put(''+index,newGroupChanges);
    		}
    		
    	}
    	
    	Map<String,List<Change_Request__c>> groupVsChangeRequestListFiltered = new Map<String,List<Change_Request__c>>();
    	Integer theIndex = 1;
    	
    	for(String groupName : groupVsChangeRequestList.keySet()){
    		if(groupVsChangeRequestList.get(groupName).size()==1){
    			if(groupVsChangeRequestListFiltered.get('Independent')==null){
    				groupVsChangeRequestListFiltered.put('Independent',new List<Change_Request__c>());
    			}
    			groupVsChangeRequestListFiltered.get('Independent').addAll(groupVsChangeRequestList.get(groupName));
    			
    		}else if(groupVsChangeRequestList.get(groupName).size()>1){
    			groupVsChangeRequestListFiltered.put('Group-'+theIndex,groupVsChangeRequestList.get(groupName));
    			theIndex++;
    		}
    	}
    	
    	return getGroupElements(groupVsChangeRequestListFiltered,changeRequestVsComponents);
    	//return groupVsChangeRequestListFiltered;      
    }
    
    public static List<GroupElement> getGroupElements(Map<String,List<Change_Request__c>> groupVsChangeRequestListFiltered, Map<Id,Set<String>> changeRequestVsComponents){
			List<GroupElement> groupElements = new List<GroupElement>();			
			for(String groupName : groupVsChangeRequestListFiltered.keySet()){
				List<Change_Request__c> changeRequests = groupVsChangeRequestListFiltered.get(groupName);
				List<GroupElement.ChangeRequest> changeRequestList = new List<GroupElement.ChangeRequest>();
				for(Change_Request__c cr : changeRequests){
					Set<String> allComponents = getAllComponentsExceptThisCR(changeRequests,changeRequestVsComponents,cr);
					List<String> commonComponents = new List<String>();
					for(String componentFromChangeRequest : changeRequestVsComponents.get(cr.Id)){
						if(allComponents.contains(componentFromChangeRequest)){
							commonComponents.add(componentFromChangeRequest);
						}	
					}						
					commonComponents.sort();			
					
					GroupElement.ChangeRequest groupElementChangeRequest = new GroupElement.ChangeRequest(cr, commonComponents);
					changeRequestList.add(groupElementChangeRequest);
				}	
				GroupElement theGroupElement = new GroupElement(changeRequestList,groupName);
				groupElements.add(theGroupElement);							
			}			
			return groupElements;    
    }
    
    
    public static Set<String> getAllComponentsExceptThisCR(List<Change_Request__c> changeRequests, Map<Id,Set<String>> changeRequestVsComponents, Change_Request__c changeRequest){
    	Set<String> allComponents = new Set<String>();
    	for(Change_Request__c cr : changeRequests){
    		if(cr.Id != changeRequest.Id){
	    		allComponents.addAll(changeRequestVsComponents.get(cr.Id));
    		}
    	}
    	return allComponents;
    } 
    
    
    
    public static Boolean hasCommonComponents(Set<String> compareSet1, Set<String> compareSet2){
    	for(String temp : compareSet1){
    		if(compareSet2.contains(temp)){
    			return true;
    		}
    	}
    	return false;
    }
    
}