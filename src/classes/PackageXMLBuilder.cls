public with sharing class PackageXMLBuilder {
	
	public class Element{
		public String elementName {get;set;}
		public String apiVersion  {get;set;}		
		public Element(String elementName,String apiVersion){
			this.elementName = elementName;
			this.apiVersion = apiVersion;
		}
		public Element(String elementName){
			this.elementName = elementName;
		}
	}
	
	public static void test(){
		new PackageXMLBuilder().getXML([select id from Change_Request__c WHERE Id='a012800000JbNUX'],[
			Select Id, 
				Source_org__r.Username__c,
				Source_org__r.Password__c,
				Source_org__r.Type__c,
				Target_org__r.Username__c,
				Target_org__r.Password__c,
				Target_org__r.Type__c
			From Connection__c WHERE Id='a042800000BSAg4'
		][0]);
	} 
	
	public String getXML(List<Change_Request__c> changeRequests, Connection__c connection){
		Map<String,Set<Element>> metadataItems = new Map<String,Set<Element>>();		
		List<String> commonProfiles = MetadataSyncService.getCommonProfiles(connection);  
		String xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>';
		xmlHeader +='<Package xmlns="http://soap.sforce.com/2006/04/metadata">';
		String xmlFooter = '</Package>';
		
		for(Component__c component : [SELECT Id,Component_Name__c,
													Type__c
									  From Component__c WHERE Change_Request__c in :changeRequests]){	
			if(metadataItems.get(component.Type__c)==null){
				metadataItems.put(component.Type__c,new Set<Element>());
			}																	
			metadataItems.get(component.Type__c).add(new Element(component.Component_Name__c));								
		}
		metadataItems.put('Profile',new Set<Element>());  		
		for(String profile : commonProfiles){
			metadataItems.get('Profile').add(new Element(profile));
		} 
		System.debug('MetadataItems-->'+JSON.serializePretty(metadataItems));
		System.debug('PackageXML-->'+(xmlHeader + getXMLBody(metadataItems) + xmlFooter)); 		
		return (xmlHeader + getXMLBody(metadataItems) + xmlFooter).escapeXML();  		
		
	}
	
	public String getXMLBody(Map<String,Set<Element>> metadataItems){
		String body ='';
		for(String metadata : metadataItems.keySet()){
			body += '<types>';
				for(Element elem : metadataItems.get(metadata) ){
					body += '<members>'+elem.elementName+'</members>';
				}
				body +='<name>'+metadata+'</name>';
			body +='</types>';
		}
		body +='<version>35.0</version>';
		return body;
	}
	
	
	
	
	
	
	
	
    
}