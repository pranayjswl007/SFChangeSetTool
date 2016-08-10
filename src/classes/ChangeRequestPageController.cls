public with sharing class ChangeRequestPageController {
    
    public Change_Request__c changeRequest {get;set;}
    
    public Map<String,String> sobjectMap {get;set;}
    
    public String sobjectIdOrEnum {get;set;} 
     
    public List<SelectOption> fieldList {get;set;} 
    
    public List<SelectOption> customObjects {get;set;}
    
    public String selectedField {get;set;}
    
    public List<SelectOption> componentTypes {get;set;}
    
    public String selectedComponentType {get;set;}
    
    public List<Component__c> getComponents(){
        return [SELECT Id, Component_Name__c,Type__c FROM Component__c 
                        WHERE Change_Request__c =:changeRequest.Id Order by Type__c, Component_Name__c ];
        return null;
    }
    
    public ChangeRequestPageController(ApexPages.StandardController std){
        fieldList = new List<SelectOption>();
        sobjectMap = new Map<String,String>();
        fieldList.add(new SelectOption('','-NONE-'));
        changeRequest = (Change_Request__c)std.getRecord();
        componentTypes = new List<SelectOption>();
        if(std.getId()!=null){
            changeRequest = [Select Id,Name , Salesforce_Org__c ,CR_ID__c, Status__c From Change_Request__c WHERE ID=:std.getId()];
            populateCustomObjects();
        }
        populateComponentsTypes();
        
        
    }
    
    public PageReference saveRecord(){
        upsert changeRequest;
        return null;
    }
        
    public void populateCustomObjects(){
            customObjects  = new List<SelectOption>();
            if(changeRequest.Id !=null){
                customObjects.add(new SelectOption('User','User')); 
                customObjects.add(new SelectOption('Quote','Quote')); 
                customObjects.add(new SelectOption('Account','Account')); 
                customObjects.add(new SelectOption('Opportunity','Opportunity'));
                customObjects.add(new SelectOption('Contact','Contact'));
                customObjects.add(new SelectOption('OrderItem','OrderItem'));
                customObjects.add(new SelectOption('Order','Order'));
                
                                                                    
                Id salesforceOrgId = [Select Salesforce_Org__c From Change_Request__c WHERE Id=:changeRequest.Id][0].Salesforce_Org__c;
                Salesforce_Org__c sfOrg = [Select Username__c,Password__c,Type__c From Salesforce_Org__c WHERE Id=:salesforceOrgId ];
                MetadataSyncService.SFOrgLogin  sfOrgLogin = MetadataSyncService.getSessionId(sfOrg.Username__c,sfOrg.Password__c,(sfOrg.Type__c=='Production'?'login':'test'));
                Map<String,String> result = MetadataSyncService.getSObjects(sfOrgLogin);
                for(String key: result.keySet()){
                    customObjects.add(new SelectOption(key,result.get(key)));
                    sobjectMap.put(key,result.get(key));
                }
            }
    }
    
 
    @RemoteAction
    public static List<MetadataSyncService.Option> refreshFieldList(String changeRequestId,String sobjectIdOrEnum){
        List<MetadataSyncService.Option> fieldList = new List<MetadataSyncService.Option>();        
        if(changeRequestId !=null){
            Id salesforceOrgId = [Select Salesforce_Org__c From Change_Request__c WHERE Id=:changeRequestId][0].Salesforce_Org__c;
            Salesforce_Org__c sfOrg = [Select Username__c,Password__c,Type__c From Salesforce_Org__c WHERE Id=:salesforceOrgId ];
            MetadataSyncService.SFOrgLogin  sfOrgLogin = MetadataSyncService.getSessionId(sfOrg.Username__c,sfOrg.Password__c,(sfOrg.Type__c=='Production'?'login':'test'));
            List<String> result = MetadataSyncService.getCustomFields(sfOrgLogin,sobjectIdOrEnum);
            fieldList.add(new MetadataSyncService.Option('','-NONE-'));
            for(String str: result){
                fieldList.add(new MetadataSyncService.Option(str,str.split('\\.')[1]));
            }
        }
        markExistingComponents(changeRequestId,fieldList,'CustomField');
        return fieldList;       
    }
    
    
    @RemoteAction
    public static Map<String,Object>  getComponents(String changeRequestId){
        Id salesforceOrgId = [Select Salesforce_Org__c From Change_Request__c WHERE Id=:changeRequestId][0].Salesforce_Org__c;
        Salesforce_Org__c sfOrg = [Select Username__c,Password__c,Type__c From Salesforce_Org__c WHERE Id=:salesforceOrgId ];
        MetadataSyncService.SFOrgLogin  sfOrgLogin = MetadataSyncService.getSessionId(sfOrg.Username__c,sfOrg.Password__c,(sfOrg.Type__c=='Production'?'login':'test'));
        Map<String,Object> result =  MetadataSyncService.getMetadataElements(sfOrgLogin);
        Set<String> existingComponents = new Set<String>();
        for(Component__c component: [Select Id, Component_Name__c From Component__c WHERE Change_Request__c =:changeRequestId]){
            existingComponents.add(component.Component_Name__c.toLowerCase());
        } 
        for(String key : result.keySet()){ 
            List<MetadataSyncService.Option> options = (List<MetadataSyncService.Option>)result.get(key);
            for(MetadataSyncService.Option option : options){
                if(existingComponents.contains(option.value.split('\\.')[0].toLowerCase())){
                    option.IsSelected = true;
                }
            } 
        }
        
        return result;
        
    }
    
    
    @RemoteAction
    public static List<MetadataSyncService.Option>  getOtherComponents(String changeRequestId, String typeOfMetadataComponent){
        Map<String,String> toolingApiComponents = getToolingApiConfig();
        List<MetadataSyncService.Option> result = new List<MetadataSyncService.Option> ();
        Id salesforceOrgId = [Select Salesforce_Org__c From Change_Request__c WHERE Id=:changeRequestId][0].Salesforce_Org__c;
        Salesforce_Org__c sfOrg = [Select Username__c,Password__c,Type__c From Salesforce_Org__c WHERE Id=:salesforceOrgId ];
        MetadataSyncService.SFOrgLogin  sfOrgLogin = MetadataSyncService.getSessionId(sfOrg.Username__c,sfOrg.Password__c,(sfOrg.Type__c=='Production'?'login':'test'));
        System.debug('FoundInToolingApi-->'+(toolingApiComponents.keySet().contains(typeOfMetadataComponent)));
        if( toolingApiComponents.keySet().contains(typeOfMetadataComponent)){
            String valueField = toolingApiComponents.get(typeOfMetadataComponent).split(':')[0];
            String labelField = toolingApiComponents.get(typeOfMetadataComponent).split(':')[1];                
            result =  MetadataSyncService.getMetadataComponentsByToolingApi(sfOrgLogin,typeOfMetadataComponent,valueField,labelField);  
        }else {
            result = MetadataSyncService.getMetadataComponentsByMetadataApi(sfOrgLogin,typeOfMetadataComponent,'fullName');
        }
        markExistingComponents(changeRequestId,result,typeOfMetadataComponent);
        return result; 
        
    }
    
    private static void markExistingComponents( String changeRequestId, List<MetadataSyncService.Option> result,String typeOfMetadataComponent){
        Set<String> existingComponents = new Set<String>();
        for(Component__c component: [Select Id, Component_Name__c From Component__c WHERE Change_Request__c =:changeRequestId AND Type__c=:typeOfMetadataComponent]){
            existingComponents.add(component.Component_Name__c.toLowerCase());
        } 
        for(MetadataSyncService.Option option : result){
            if(existingComponents.contains(option.value.toLowerCase())){
                option.isSelected = true;
            }
        }
    }
      
    public static Map<String,String> getToolingApiConfig(){
        Map<String,String> toolingApiConfig = new Map<String,String>();     
        toolingApiConfig.put('EmailTemplate','FullName:Name');                  
        return toolingApiConfig;
    }
         
    private void populateComponentsTypes(){
            for(MetadataSyncService.Option option : MetadataSyncService.getMetadataComponents()){
                if(option.value != 'ApexTrigger'
                        && option.value != 'ApexComponent'
                        && option.value != 'ApexPage'
                        && option.value != 'ApexClass'
                        && option.value != 'CustomField' ){
                    componentTypes.add(new SelectOption(option.value,option.label));
                }
            }                   
    }   
    
    public class Component{
        public Component__c component{get;set;}
        public Boolean isSelected = false;
        public Component(Component__c component, Boolean isSelected){
            this.component = component;
            this.isSelected = isSelected;
        } 
    }
    
    @RemoteAction
    public static String updateComponents(String changeRequestId,List<String> components){  
        Set<String> existingComponents = new Set<String>();
        for(Component__c component: [Select Id, Component_Name__c, Type__c From Component__c WHERE Change_Request__c =:changeRequestId]){
            existingComponents.add(component.Type__c.toLowerCase()+':'+component.Component_Name__c.toLowerCase());
        }                                               
        List<Component__c> componentsToBeInserted = new List<Component__c>();
        for(String component : components){
            String componentType = '';
            if(component.toLowerCase().endsWith('.trigger')){
                componentType = 'ApexTrigger';
            }else if (component.toLowerCase().endsWith('.page')){
                componentType = 'ApexPage';
            }else if (component.toLowerCase().endsWith('.cls')){
                componentType = 'ApexClass';
            }else if (component.toLowerCase().endsWith('.component')){
                componentType = 'ApexComponent';
            }
            component = component.split('\\.')[0];
            if(!existingComponents.contains((componentType.toLowerCase()+':'+component.toLowerCase()))){
                componentsToBeInserted.add(new Component__c(Change_Request__c=changeRequestId,Component_Name__c=component,Type__c=componentType));
            }
        }
        insert componentsToBeInserted;
        return 'success';       
    }
    
    @RemoteAction
    public static String addOtherComponents(String changeRequestId,String typeOfMetadata, List<String> components){
        Set<String> existingComponentsSet = new Set<String>();                                                      
        for(Component__c component : [Select id, Component_Name__c,Type__c From Component__c 
                                                        WHERE Change_Request__c =:changeRequestId]){
            existingComponentsSet.add((component.type__c+':'+component.Component_Name__c).toLowerCase());
        }
        List<Component__c> componentsToBeInserted = new List<Component__c>();
        for(String component : components){         
            if(!existingComponentsSet.contains((typeOfMetadata+':'+component).toLowerCase())){
                componentsToBeInserted.add(new Component__c(Change_Request__c=changeRequestId,Component_Name__c=component,Type__c=typeOfMetadata));
            }
        }
        upsert componentsToBeInserted;
        return 'success';       
    }
    
    
    public PageReference cancel(){
        return new PageReference('/'+Change_Request__c.getSObjectType().getDescribe().getKeyPrefix());
    }

    /**
     * @description : Deletes the record.
     * @param       : recordid is the id of the record to be deleted.
     * @return      :   
     */
     public PageReference deleteRecord(){
        try{
            String recordId = ApexPages.currentPage().getParameters().get('recordId');
            if(recordId!=null && recordId.trim()!=''){
                Id theRecordId = recordId;
                SObject theSObject = theRecordId.getSObjectType().newSObject(theRecordId);
                System.debug('Deleting the record-->'+theSObject);
                delete theSObject;
                if((theRecordId.getSObjectType()+'')=='Change_Request__c'){
                    return new PageReference('/'+Change_Request__c.getSObjectType().getDescribe().getKeyPrefix());
                }                 
            }           
        }catch(DMLException dmle){
            System.debug('DMLEXCEPTION-->'+dmle.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,dmle.getDMLMessage(0)));
        }catch(Exception ex) {
            System.debug('EXCEPTION-->'+ex.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getMessage()));                         
        }
        return null; 
     } 
    
    
    
    
    
    
    
        
}