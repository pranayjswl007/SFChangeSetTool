public class GroupElement {

	public String groupName 				  {get;set;}
	public List<ChangeRequest> changeRequests {get;set;}
	public GroupElement(List<ChangeRequest> changeRequests,String groupName){
		this.changeRequests = changeRequests;
		this.groupName = groupName;
	}
	
	public class ChangeRequest{
		public Change_Request__c changeRequest {set;get;}
		public List<String> commonComponents {get;set;}
		public String getCommonCompoentString(){
			String commonComponentStr = '';			
			for(String str : commonComponents){
				commonComponentStr +=str+',';
			}
			return commonComponentStr;
		}			
		public ChangeRequest(Change_Request__c changeRequest,List<String> commonComponents){
			this.changeRequest = changeRequest;
			this.commonComponents = commonComponents;
		}			
	}
   
}