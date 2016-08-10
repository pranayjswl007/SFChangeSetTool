public with sharing class MetadataSyncService {
  
  	     /**
         * @description : This method does the login to sf orgs and provides session id and 
         *  instance url wrapped in SFOrgLogin wrapper instances.
         */
        @RemoteAction
        public static List<SFOrgLogin> doSFLogins(String sorgType,String susername,String spassword,String torgType,String tusername,String tpassword){
            List<SFOrgLogin> sfOrgLogins = new List<SFOrgLogin>();
            sforgLogins.add(getSessionId(susername,spassword,sorgType));
            sforgLogins.add(getSessionId(tusername,tpassword,torgType));
            return sforgLogins;
        }
        
        /**
         * @description : This gets the sesssion id and instance url from any SF org based on 
         * username, password and orgType(Production/Sandbox)
         */
        public static SFOrgLogin getSessionId(String username, String password,String orgType){
            HttpRequest req = new HttpRequest();
            HttpResponse res = new HttpResponse();
            Http http = new Http();
            
            req.setEndpoint('https://'+orgType+'.salesforce.com/services/oauth2/token');
            req.setMethod('POST');
            req.setBody('grant_type=password&client_id=3MVG9Y6d_Btp4xp6GS9EUagsYr3sSAS712UYL9IyhQa66iYWV094SBWVQrAXnGmf.QbQeg7KY9tPWw6POG14P&client_secret=1943073504765486342&username='+EncodingUtil.urlEncode(username, 'UTF-8')+'&password='+EncodingUtil.urlEncode(password, 'UTF-8'));
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            try {
                res = http.send(req);
                System.debug(res.getBody());
                Map<String,Object> response = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                SFOrgLogin sforg = new SFOrgLogin();
                sforg.sessionId = ''+response.get('access_token');
                sforg.instanceURL = ''+response.get('instance_url');
                if(sforg.sessionId == '' || sforg.sessionId == 'null'
                    || sforg.instanceURL == '' || sforg.instanceURL == 'null'){
                    throw new MetadataSyncServiceException('Username/Password is incorrect - Please check details for '+username);
                }
                return sforg;
            } catch(System.CalloutException e) {
                System.debug('Callout error: '+ e);
                System.debug(res.toString());
            }
            
            return null;
        }
        
        /**
         * @ApexClass : SFOrgLogin
         * @Description : Wrapper to hold session id and instance url.
         */
        public class SFOrgLogin{
            String sessionId;
            String instanceURL;
        }

        /**
         * @Returns the metadata options for selected metadata types.
         */
        @RemoteAction 
        public static List<Component__c> getMetadata(SFOrgLogin sforgLogin){
            List<String> metadataItems = new List<String>();
            metadataItems.add('ApexClass');
            metadataItems.add('ApexPage'); 
            metadataItems.add('ApexTrigger');
            metadataItems.add('ApexComponent');
            
            //metadataItems.add('CustomObject');
            List<Component__c> result = new List<Component__c>();
            for(String metadata : metadataItems){
                result.addAll(getComponents(sforgLogin,metadata));       
            }
            return result;
        }
        
        /**
         *@Description : For selected metadata type it returns all the entries in the org wrapped in Option(Wrapper class).
         */
        private static List<Component__c> getComponents(SFOrgLogin sforgLogin,String metadataItem){
            String query = ' SELECT Id, Name, ApiVersion FROM '+metadataItem + ' Order By Name ';
            query = EncodingUtil.urlEncode(query, 'UTF-8');
            String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v28.0/tooling/query/?q='+query,sforglogin.sessionid);
           List<Component__c> result = new List<Component__c>();
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>)responseMap.get('records');
            for(Object record : records){
                Map<String,Object> recordObj  = (Map<String,Object>) record;
                String name = ''+recordObj.get('Name');
                String apiVersion = ''+recordObj.get('ApiVersion');
                if(metadataItem == 'ApexPage'){
                	name +='.page';    
                }else if(metadataItem == 'ApexTrigger'){
                	name +='.trigger';
                }else if(metadataItem == 'ApexClass'){
                	name +='.cls';
                }else if(metadataItem == 'ApexComponent'){
                	name +='.component';
                }
               result.add(new Component__c(Component_Name__c=name,Api_Version__c=apiVersion));
            }
            return result;
        }
        
		public static void test(){
			List<Component__c> components = new List<Component__c>();
			components = getMetadata(getSessionId('cfadmin@persistent.co.in.dev1','Password_12345','test'));
			//upsert components Component_Name__c;
		}        
        
        /**
         *@description : Helps making tooling api call.
         */
        private static String makeToolingApiRequest(String endpoint,String sessionId){  
             HttpRequest req = new HttpRequest();
             //Set the tooling api endpoint  
             req.setEndpoint(endpoint);  
             /*Set authorization by using current users session Id*/  
             req.setHeader('Authorization', 'Bearer ' + sessionId);  
             req.setHeader('Content-Type', 'application/json');      
             req.setMethod('GET');  
             req.setTimeout(1000*120);
             Http http = new Http();  
             HTTPResponse res = http.send(req);  
             return res.getBody();  
       }  
       
       /**
        * @description : It returns the id of selected metadata element from target org.
        */
       private static String getTargetOrgMetadataItemId(SFOrgLogin sforgLogin,String metadataItem,String metadataType){
           String query = ' SELECT Id, Name FROM '+metadataType+' WHERE Name =\''+metadataItem+'\' ';
           query = EncodingUtil.urlEncode(query, 'UTF-8');
           String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v28.0/tooling/query/?q='+query,sforglogin.sessionid);
           Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
           List<Object> records = (List<Object>)responseMap.get('records');
           for(Object record : records){
                Map<String,Object> recordObj  = (Map<String,Object>) record;
                return ''+recordObj.get('Id');
           }
           return null;
       }
       
       /**
        * @description : It returns the code of metadata element(ApexClass,ApexTrigger or ApexPages)
        */
       private static String getCode(SFOrgLogin sforgLogin,String metadataURL){
           String result=null;
           String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v28.0/tooling/sobjects/'+metadataURL,sforglogin.sessionid);
           Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
           if(responseMap.get('Body') != null){
                result = ''+responseMap.get('Body');
           }else if(responseMap.get('Markup') != null){
               result = ''+responseMap.get('Markup');
           }
           return result;
       }
       
       @RemoteAction
       public static Code getCode(SFOrgLogin source,SFOrgLogin target,String metadataURL,String metadataItem){
           Code result = new Code();
           String metadataType = metadataURL.split('/')[0];
           String targetMetadataURL = metadataType + '/'+ getTargetOrgMetadataItemId(target,metadataItem,metadataType);
           result.sourceCode = getCode(source,metadataURL);
           result.targetCode = getCode(target,targetMetadataURL);
           return result;
       }
       
       /**
        *@ApexClass     : Code
        *@Description   : Wrapper class to hold source code and target org used for comparison  
        */
       public class Code{
           String sourceCode;
           String targetCode;
           public Code(){}
           public Code(String sourceCode,String targetCode){
               this.sourceCode = sourceCode;
               this.targetCode = targetCode;
           }
       }
       
       /**
        *@ApexClass : Option
        *@Description : Wrapper class to hold value and label of metadata element
        */
       public class Option{
           public String value{get;set;}
           public String label{get;set;}
           public Boolean isSelected {get;set;}
           public Option(String value,String label){
           	   isSelected = false;
               this.value = value;
               this.label = label;
           }
       }
       
       /**
        * @ApexClass    : MetadataSyncServiceException 
        * @Description  : Custom Exception 
        */
       public class MetadataSyncServiceException extends Exception {}
         
       /**
         * @Returns the metadata options for selected metadata types.
         */
        @RemoteAction 
        public static Map<String,Object> getMetadataElements(SFOrgLogin sforgLogin){
            List<String> metadataItems = new List<String>();
            metadataItems.add('ApexClass');
            metadataItems.add('ApexPage'); 
            metadataItems.add('ApexTrigger');
            metadataItems.add('ApexComponent');
            
            //metadataItems.add('CustomObject');
            Map<String,Object> result = new Map<String,Object>();
            for(String metadata : metadataItems){
                result.put(metadata,getOptions(sforgLogin,metadata));       
            }
            return result;
        }
        
        /**
         *@Description : For selected metadata type it returns all the entries in the org wrapped in Option(Wrapper class).
         */
        private static List<Option> getOptions(SFOrgLogin sforgLogin,String metadataItem){
        	System.debug('sforgLogin-->'+sforgLogin);
            String query = ' SELECT Id, Name FROM '+metadataItem + ' Order By Name ';
            query = EncodingUtil.urlEncode(query, 'UTF-8');
            String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v28.0/tooling/query/?q='+query,sforglogin.sessionid);
            List<Option> result = new List<Option>();
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>)responseMap.get('records');
            for(Object record : records){
            	Map<String,Object> recordObj  = (Map<String,Object>) record;
                String name = ''+recordObj.get('Name');
                if(metadataItem == 'ApexPage'){
                	name +='.page';    
                }else if(metadataItem == 'ApexTrigger'){
                	name +='.trigger';
                }else if(metadataItem == 'ApexClass'){
                	name +='.cls';
                }else if(metadataItem == 'ApexComponent'){
                	name +='.component';
                }
                result.add(new Option(name,name));
            }
            return result;
        }
        
        /**
         *@Description : For selected metadata type it returns all the entries in the org wrapped in Option(Wrapper class).
         */
        public static List<String> getCommonProfiles(Connection__c connection){  
        	List<String> result = new List<String>();      	
        	SFOrgLogin sourceOrg =  getSessionId(connection.source_Org__r.Username__c,connection.source_Org__r.Password__c,connection.source_Org__r.Type__c=='Production'?'login':'test');
        	SFOrgLogin targetOrg =  getSessionId(connection.target_Org__r.Username__c,connection.target_Org__r.Password__c,connection.target_Org__r.Type__c=='Production'?'login':'test');
        	List<String> sourceOrgProfiles = getInternalMetadata(sourceOrg,'Profile');
        	List<String> targetOrgProfiles = getInternalMetadata(targetOrg,'Profile');
        	Set<String> targetOrgProfileSet = new Set<String>();
        	targetOrgProfileSet.addAll(targetOrgProfiles);
        	for(String profile : sourceOrgProfiles){
        		if(targetOrgProfileSet.contains(profile)){
        			result.add(profile);
        		}
        	}         
            return result;
        }
        
        private static List<String> getInternalMetadata(SFOrgLogin sforgLogin,String metadataItem){
        	String query = ' SELECT Id, FullName FROM '+metadataItem + ' ';
            query = EncodingUtil.urlEncode(query, 'UTF-8');
            String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v34.0/tooling/query/?q='+query,sforglogin.sessionid);
            List<String> result = new List<String>();
            System.debug('Response-->'+response);
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>)responseMap.get('records');
            for(Object record : records){
            	Map<String,Object> recordObj  = (Map<String,Object>) record;
                String name = ''+recordObj.get('FullName');               
                result.add(name);
            }
            return result;
        }
        
        public static Map<String,String> getSObjects(SFOrgLogin sforgLogin){
        	Map<String,String> sobjects = new Map<String,String>();
        	String query = ' SELECT Id, DeveloperName FROM CustomObject ';
            query = EncodingUtil.urlEncode(query, 'UTF-8');
            String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v34.0/tooling/query/?q='+query,sforglogin.sessionid);
            List<String> result = new List<String>();
            System.debug('Response-->'+response);
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>)responseMap.get('records');
            for(Object record : records){
            	Map<String,Object> recordObj  = (Map<String,Object>) record;
                String name = ''+recordObj.get('DeveloperName')+'__c'; 
                String idOrEnum = ''+recordObj.get('Id');                               
                sobjects.put(idOrEnum,name);
            }
            return sobjects;
        }
        
        public static List<String> getCustomFields(SFOrgLogin sforgLogin,String sobjectEnumOrId){
        	List<String> fieldList = new List<String>();
        	String query = ' SELECT Id, FullName FROM CustomField WHERE TableEnumOrId= \''+sobjectEnumOrId+'\' ';
            query = EncodingUtil.urlEncode(query, 'UTF-8');
            String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v34.0/tooling/query/?q='+query,sforglogin.sessionid);
            List<String> result = new List<String>();
            System.debug('Response-->'+response);
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>)responseMap.get('records');
            for(Object record : records){
            	Map<String,Object> recordObj  = (Map<String,Object>) record;
                String name = ''+recordObj.get('FullName');                                             
                fieldList.add(name);
            }
            return fieldList;
        }
        
        public static List<Option> getMetadataComponentsByToolingApi(SFOrgLogin sforgLogin,String metadataType,String valueField,String labelField){
        	List<Option> result = new List<Option>();
        	String fieldsString = '';
        	If(valueField == labelField){
        		fieldsString = valueField;
        	}else{
        		fieldsString = labelField + ', '+ valueField;
        	}
        	String query = ' SELECT Id, '+fieldsString+' FROM '+metadataType+'';
            query = EncodingUtil.urlEncode(query, 'UTF-8');
            String response = makeToolingApiRequest(sforglogin.instanceURL+'/services/data/v34.0/tooling/query/?q='+query,sforglogin.sessionid);
            System.debug('Response-->'+response);
            Map<String,Object> responseMap = (Map<String,Object>)JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>)responseMap.get('records');
            for(Object record : records){
            	Map<String,Object> recordObj  = (Map<String,Object>) record;
                String value = ''+recordObj.get(valueField);
                String label = ''+recordObj.get(labelField);                                             
                result.add(new Option(value,label));
            }
            return result;
        }
        
        public static List<String> getDataBetweenTags(String tagName, String str){
	         System.debug('Text-->'+str);
		     // Matcher m = Pattern.compile('(<'+tagName+'>)([\\s\\S]*?)(</'+tagName+'>)').matcher(str);
		     Matcher m = Pattern.compile('<'+tagName+'>(.+?)</'+tagName+'>').matcher(str);
		     List<String> results = new List<String>();
			 while(m.find()){
			 	//results.add(str.substring(m.start(), m.end()));
			 	results.add(m.group(1));
			 } 
			 return results;		 
		}
    
	    public static List<Option> getMetadataComponentsByMetadataApi(SFOrgLogin sforgLogin,String metadataType,String valueField){
	        String sessionId = sforgLogin.sessionid;      
	        String requestXML = '<?xml version="1.0" encoding="UTF-8"?><env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><env:Header><SessionHeader xmlns="http://soap.sforce.com/2006/04/metadata"><sessionId>'+sessionId+'</sessionId></SessionHeader></env:Header><env:Body><listMetadata xmlns="http://soap.sforce.com/2006/04/metadata"><queries><type>'+metadataType+'</type></queries><asOfVersion>34.0</asOfVersion></listMetadata></env:Body></env:Envelope>';
	        HttpRequest req = new HttpRequest();
	        req.setHeader('SOAPAction','""');
	        //Set the tooling api endpoint  
	        req.setEndpoint(sforgLogin.instanceURL+'/services/Soap/m/35.0');        
	        req.setHeader('Content-Type', 'text/xml;charset=UTF-8');      
	        req.setMethod('POST');
	        req.setTimeout(1000*120);
	        req.setBody(requestXML);  
	        Http http = new Http();  
	        HTTPResponse res = http.send(req);  
	        List<String> results = getDataBetweenTags('fullName',res.getBody());
	        results.sort();
	        List<Option> options = new List<Option>();
	        for(String str : results){
	        	options.add(new Option(str,str));
	        } 
	        return options;
	    }
	    
	    public static List<Option> getMetadataComponents(){
	        String requestXML = '<?xml version="1.0" encoding="UTF-8"?><env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><env:Header><SessionHeader xmlns="http://soap.sforce.com/2006/04/metadata"><sessionId>'+UserInfo.getSessionId()+'</sessionId></SessionHeader></env:Header><env:Body><describeMetadata xmlns="http://soap.sforce.com/2006/04/metadata"><asOfVersion>34.0</asOfVersion></describeMetadata></env:Body></env:Envelope>';
	        HttpRequest req = new HttpRequest();
	        req.setHeader('SOAPAction','""');
	        //Set the tooling api endpoint  
	        req.setEndpoint(URL.getSalesforceBaseUrl().toExternalForm()+'/services/Soap/m/35.0');        
	        req.setHeader('Content-Type', 'text/xml;charset=UTF-8');      
	        req.setMethod('POST');
	        req.setTimeout(1000*120);
	        req.setBody(requestXML);  
	        Http http = new Http();  
	        HTTPResponse res = http.send(req);  
	        List<String> results = getDataBetweenTags('xmlName',res.getBody());
	        results.addAll(getDataBetweenTags('childXmlNames',res.getBody()));
	        results.sort();
	        List<Option> options = new List<Option>();
	        for(String str : results){
	        	options.add(new Option(str,str));
	        } 
	        return options;
	    }
	    
        
        
     
}