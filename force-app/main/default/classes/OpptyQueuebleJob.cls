public with sharing class OpptyQueuebleJob implements Queueable, Database.AllowsCallouts{

    public class CalloutRequestBody{
        public CalloutRequestBody(){
            this.values = new Map<String,Object>();
        }
        public Map<String,Object> values{get;set;}
    }
    
    /*
     * Opportunity passed on class creation from trigger
	 */
    private Opportunity opptyRecord{get;Set;}
    
   
    public OpptyQueuebleJob(Opportunity opptyRecord) {
        this.opptyRecord = opptyRecord;
    }

    public void execute(QueueableContext context) { 
    	//creates the callout method
        String reqBody = JSON.serialize(createFromOppty(this.opptyRecord));
        
       // Gets the already created Callout_Details__c object
        Callout_Details__c currentCallout = [Select Id, Status__c, Sent_on__c, Response__c, Opportunity__c,
                                     Job_ID__c From Callout_Details__c Where Job_ID__c = :context.getJobId()];
        
        //Starting time (to get Duration__c)
        Long start = System.now().getTime();
        
        //4 - tries to make the REST call
        try{
            Http h = new Http();
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            //USE http://requestb.in
            request.setEndpoint('https://enr1t01ojegi7.x.pipedream.net');
            request.setTimeout(60000);
            request.setBody(reqBody);
            HttpResponse response = h.send(request);
            
            //4a - Response OK
            if(response.getStatusCode() == 200){
            	currentCallout.status__c = 'OK';
            //4b - Reponse KO
            }else{
                currentCallout.status__c = 'KO';
            }
            // saves the response body
            currentCallout.Response__c = response.getBody();
        }catch(Exception e){
        	//callout failed (Example - timeout)
            currentCallout.status__c = 'Failed';
            currentCallout.Response__c = e.getStackTraceString().replace('\n',' / ')+' - '+e.getMessage();
            

            ID jobID = System.enqueueJob(new OpptyQueuebleJob(this.opptyRecord));
            Callout_Details__c retry = new Callout_Details__c(Job_ID__c = jobID, 
                                                 Opportunity__c = this.opptyRecord.Id,
												Status__c = 'Queued');
            insert retry;
        }
   
        currentCallout.Sent_on__c = System.now();
        update currentCallout;
        
    }
    
    private static CalloutRequestBody createFromOppty(Opportunity opptyRecord){
        CalloutRequestBody calloutRequestBody = new CalloutRequestBody();
        Map<String, Schema.SObjectField> fields = Opportunity.getSobjectType().getDescribe().fields.getMap();
        for(String key : fields.keyset()){
            Object obj = opptyRecord.get(key);
            if(obj != null){
            	CalloutRequestBody.values.put(key.replace('__c','').toLowerCase(), obj);
			}
        }
        return CalloutRequestBody;
    }

}