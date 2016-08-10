public with sharing class SFDeploymentController {
	
	public static List<GroupElement> groupedChanges {get;set;}
	public String connectionId {get;set;}
	
	public SFDeploymentController(){		
		groupedChanges = ChangeRequestService.groupChangeRequests([Select Id,Status__c,CR_ID__c,Name From Change_Request__c 
					WHERE Status__c='UATReady' OR Status__c='UAT'  OR Status__c= 'MoveToLive']);
	}
	
	public List<SelectOption> getBuilds() {
            List<SelectOption> options = new List<SelectOption>();
            options.add(new SelectOption('','-None-'));
            for(Build__c build : [Select Id, Name From Build__c]){
            	options.add(new SelectOption(build.Id,build.Name));
            }
            return options;
        }
	
	@RemoteAction
	public static Map<String,List<Change_Request__c>> getChangeRequests(){
		Map<String,List<Change_Request__c>> result = new Map<String,List<Change_Request__c>>();
		for(Change_Request__c cr : [Select Id, Name, Status__c From Change_Request__c]){
			if(result.get(cr.Status__c)==null){  
				result.put(cr.Status__c,new List<Change_Request__c>());
			}
			result.get(cr.Status__c).add(cr);
		}
		return result;
	}    
		
	@RemoteAction 
	public static String upsertBuild(List<String> changeSetRequestIds,String buildId){
	    Build__c build;
	    Map<Id,Boolean> existingCrIdsVsConsidered = new Map<Id,Boolean>();
	    if(buildId!=null && buildId.trim() != ''){
		    build = new Build__c(Id=buildId);
		    for(Build_Change_request__c bcr : [Select Id, Change_Request__c From Build_Change_request__c WHERE Build__c =:buildId]){
		        existingCrIdsVsConsidered.put(bcr.Change_Request__c,false);
		    }
	        
	    }else{
	        build = new Build__c(); 
	    }
		upsert build;
		List<Build_Change_Request__c> buildChangeRequests = new List<Build_Change_Request__c>();
		for(String crId : changeSetRequestIds){
		    if(!existingCrIdsVsConsidered.keySet().contains(crId)){
			    buildChangeRequests.add(new Build_Change_Request__c(Build__c=build.Id,Change_Request__c = crId));
		    }else if(existingCrIdsVsConsidered.keySet().contains(crId)){
		        existingCrIdsVsConsidered.put(crId,true);
		    }
		}
		Set<Id> crsToBeRemoved = new Set<Id>(); 
		for(String key : existingCrIdsVsConsidered.keySet()){
		    if(!existingCrIdsVsConsidered.get(key)){
		        crsToBeRemoved.add(key);
		    }
		}
		delete [Select id From Build_Change_Request__c WHERE Change_Request__c in :crsToBeRemoved];
		insert buildChangeRequests;
		return build.Id;		
	}
	
	@RemoteAction 
	public static List<String> getExistingCRs(String buildId){
	    Set<String> existingCrIds = new Set<String>();
	    if(buildId!=null && buildId.trim() != ''){
		    for(Build_Change_request__c bcr : [Select Id, Change_Request__c From Build_Change_request__c WHERE Build__c =:buildId]){
		        existingCrIds.add(''+bcr.Change_Request__c);
		    }
	    }
	    List<String>  existingCrList = new List<String>();
	    existingCrList.addAll(existingCrIds);
	    return existingCrList;
	    
	}
	
	
	public PageReference groupChanges(){
		String crIdListString = Apexpages.currentPage().getParameters().get('crIdListString');
		List<String> crIdList = crIdListString.split(',');
		groupedChanges =  ChangeRequestService.groupChangeRequests([Select Id,Status__c,CR_ID__c,Name From Change_Request__c WHERE Id in :crIdList]);
		return null;
	}
	
	
}