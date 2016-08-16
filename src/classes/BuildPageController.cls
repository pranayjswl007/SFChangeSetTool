public with sharing class BuildPageController {
	 
	public Build__c build {get;set;} //adding comment form work pc 
	public Boolean isEdit {get;set;}//This is master branch
	public List<Build_Change_Request__c> buildChangeRequests {get;set;}
    public BuildPageController(ApexPages.StandardController std){
		if(std.getId()!=null){
		   build = [Select Id,Check_Only__c,Connection__c,Description__c,Test_Options__c,TestClasses__c,Name From Build__c WHERE ID=:std.getId()];	
		   populateBuildChangeRequests();
		   String readOnlyMode = ApexPages.currentPage().getParameters().get('readOnlyMode');	
		   if(readOnlyMode != null && readOnlyMode == 'true'){
		   	   isEdit = false;
		   }else{
			   isEdit = true;	
		   }
		} 
	} 
	
	private void populateBuildChangeRequests(){
		buildChangeRequests = [Select Id, Change_Request__r.Name,Change_Request__r.CR_ID__c From Build_Change_Request__c WHERE Build__c =:build.Id];
	}
	
	public PageReference save(){
		upsert build;
		isEdit = false; 
		return null;
	}
	
	public PageReference edit(){
		isEdit = true;
		return null;
	}
	
	/**
	* This method will navigate the page in view only mode since this method got called from 
	* the page which has been configured to be opened in view mode when clicked on any build object record.
	*/
	public PageReference viewModeActionMethod(){
		isEdit = false;
		PageReference pg =  new PageReference('/apex/BuildPage?id='+build.Id+'&readOnlyMode=true');
		pg.setRedirect(true);
		return pg;  
	}
	
	
	@RemoteAction
	public static String getDeploymentStatus(){
		HttpRequest req = new HttpRequest();
	    req.setEndpoint('https://kmforce4.herokuapp.com/DeployCode');
	    req.setMethod('GET');     
	    Http http = new Http();
	    HTTPResponse res = http.send(req);
	    System.debug(res.getBody());	
	    return res.getBody(); 
	}
	 
	public PageReference showMessage(){
		String message = ApexPages.currentPage().getParameters().get('message');
		String isError = ApexPages.currentPage().getParameters().get('isError');
		if(isError == 'true'){
			ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, message);
	        ApexPages.addMessage(msg);
		}else{
			ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Confirm, message);
	        ApexPages.addMessage(msg);
		}		 
		return null;
	}
	
	
	@RemoteAction
	public static String startDeployment(String buildId){
		Build__c build = [SELECT ID, (Select Id, Change_Request__c From Build_Change_Requests__r ), TestClasses__c, Test_Options__c,Connection__c FROM Build__c WHERE Id=:buildId][0];
		Set<Id> changeSetRequestIds = new Set<Id>();
		for(Build_Change_Request__c bcr : build.Build_Change_Requests__r){
			changeSetRequestIds.add(bcr.Change_Request__c);
		}
		return ChangeRequestService.deployChangeRequests([select id from Change_Request__c WHERE Id in : changeSetRequestIds],[
			Select Id, 
				Source_org__r.Username__c,
				Source_org__r.Password__c,
				Source_org__r.Type__c,
				Target_org__r.Username__c,
				Target_org__r.Password__c,
				Target_org__r.Type__c
			From Connection__c WHERE Id=:build.Connection__c
		][0],false,build.TestClasses__c,build.Test_Options__c);	
		
	}  
	
	@RemoteAction
	public static Object startValidation(String buildId){
		Build__c build = [SELECT ID, (Select Id, Change_Request__c From Build_Change_Requests__r ), TestClasses__c, Test_Options__c, Connection__c FROM Build__c WHERE Id=:buildId][0];
		Set<Id> changeSetRequestIds = new Set<Id>();
		for(Build_Change_Request__c bcr : build.Build_Change_Requests__r){
			changeSetRequestIds.add(bcr.Change_Request__c);
		}
		return ChangeRequestService.deployChangeRequests([select id from Change_Request__c WHERE Id in : changeSetRequestIds],[
			Select Id, 
				Source_org__r.Username__c,
				Source_org__r.Password__c,
				Source_org__r.Type__c,
				Target_org__r.Username__c,
				Target_org__r.Password__c,
				Target_org__r.Type__c
			From Connection__c WHERE Id=:build.Connection__c
		][0],true,build.TestClasses__c,build.Test_Options__c);	
	}
	
}