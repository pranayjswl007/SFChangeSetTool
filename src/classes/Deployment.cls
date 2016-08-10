public with sharing class Deployment {
    public String packageXML {get;set;}
    public Salesforce_Org__c sourceOrg {get;set;}
    public Salesforce_Org__c targetOrg {get;set;}
    public String testClassesToBeExecuted {get;set;}  
    public Boolean isValidate  {get;set;} 
    public String testOptions {get;set;}     
}