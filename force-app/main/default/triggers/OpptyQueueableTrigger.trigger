/*
 *   Whenever a Opportunity Stage is Closed Won ,Send a callout to an external service
 */
 

trigger OpptyQueueableTrigger on Opportunity(after insert, after update) {
    List < Callout_Details__c > scheduledCalloutDetails = new List < Callout_Details__c > ();
    for (Integer i = 0; i < Trigger.new.size(); i++) {
        if ((Trigger.isInsert || Trigger.new[i].StageName != Trigger.old[i].StageName) &&
            Trigger.new[i].StageName == 'Closed Won') {
            ID jobID = System.enqueueJob(new OpptyQueuebleJob(Trigger.new[i]));
            scheduledCalloutDetails.add(new Callout_Details__c(Job_ID__c = jobID,
                Opportunity__c = Trigger.new[i].Id,
                Status__c = 'Queued'));
        }
    }

    if(scheduledCalloutDetails.size()>0){
        insert scheduledCalloutDetails;
    }
}