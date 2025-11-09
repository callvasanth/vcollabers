public class ChatwootQueueable implements Queueable, Database.AllowsCallouts {
    private Id jobCardId;
    public ChatwootQueueable(Id jcId) {
        this.jobCardId = jcId;
    }

    public void execute(QueueableContext ctx) {
        try {
            Job_Card__c jc = [
                SELECT Id, Name,
                       
                       Vehicle__r.Vehicle_Owner__r.Phone
                FROM Job_Card__c
                WHERE Id = :jobCardId
                LIMIT 1
            ];

            // prefer explicit Customer_Mobile__c; fallback to Vehicle->Owner->Phone
            String phone = jc.Vehicle__r.Vehicle_Owner__r.Phone;
            if (String.isBlank(phone)) {
                if (jc.Vehicle__r != null && jc.Vehicle__r.Vehicle_Owner__r != null) {
                    phone = jc.Vehicle__r.Vehicle_Owner__r.Phone;
                }
            }
            if (String.isBlank(phone)) {
                System.debug('ChatwootQueueable: no phone for Job_Card ' + jc.Id);
                return;
            }

            String message = 'Job card for your vehicle has been created. Shall we proceed? Reply *approve* to confirm or *not approved* to decline.';
            ChatwootService.sendJobMessageByPhone(phone, message);

            // optional: mark as sent
            try {
                jc = new Job_Card__c(Id = jc.Id, Chatwoot_Sent__c = true);
                update jc;
            } catch (Exception e) {
                System.debug('ChatwootQueueable: failed to mark Chatwoot_Sent__c - ' + e.getMessage());
            }
        } catch (Exception ex) {
            System.debug('ChatwootQueueable error: ' + ex.getMessage());
        }
    }
}