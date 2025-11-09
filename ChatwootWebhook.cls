@RestResource(urlMapping='/chatwoot/*')
global with sharing class ChatwootWebhook {
    
    @HttpPost
    global static String handleWebhook() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
        
        String eventType = String.valueOf(payload.get('event'));
        
        if (eventType == 'conversation_created' || eventType == 'conversation_updated') {
            handleConversation(payload);
        } else if (eventType == 'message_created') {
            handleMessage(payload);
        }
        
        System.debug('payload: ' + payload);
        return 'ok';
    }
    
    // ===============================
    // Conversation Handler
    // ===============================
    private static void handleConversation(Map<String, Object> payload) {
        // Sometimes Chatwoot sends "conversation" nested, sometimes at root
        Map<String, Object> convData;
        if (payload.containsKey('conversation')) {
            convData = (Map<String, Object>) payload.get('conversation');
        } else {
            convData = payload; // fallback to root
        }

        if (convData == null) {
            System.debug('No conversation data in payload: ' + JSON.serialize(payload));
            return;
        }
			
System.debug('ConIdinConv: ' + String.valueOf(convData.get('id')));
        Chatwoot_Conversation__c conv = new Chatwoot_Conversation__c(
            Chatwoot_ID__c = String.valueOf(convData.get('id')),
            Status__c      = String.valueOf(convData.get('status'))
            /*CreatedAt__c = convData.get('created_at') != null 
                ? DateTime.newInstanceGMT(((Long)convData.get('created_at')) * 1000) 
                : null,
            UpdatedAt__c = convData.get('updated_at') != null 
                ? DateTime.newInstanceGMT(((Long)convData.get('updated_at')) * 1000) 
                : null*/
        );
        
        System.debug('Upserting conversation: ' + conv);
        upsert conv Chatwoot_ID__c;
    }
    
    // ===============================
    // Message Handler
    // ===============================
private static void handleMessage(Map<String, Object> payload) { 
    
    // Handle different payload formats 
    Map<String, Object> msgData; 
    if (payload.containsKey('message')) { 
        msgData = (Map<String, Object>) payload.get('message'); 
    } else { 
        msgData = payload; // fallback: use root level 
    } 
    
    if (msgData == null) { 
        System.debug('No message data in payload: ' + JSON.serialize(payload)); 
        return; 
    } 
    
    Map<String, Object> convData;
        if (payload.containsKey('conversation')) {
            convData = (Map<String, Object>) payload.get('conversation');
        } else {
            convData = payload; // fallback to root
        }

        if (convData == null) {
            System.debug('No conversation data in payload: ' + JSON.serialize(payload));
            return;
        }
	System.debug('ConIdinmsg: ' + String.valueOf(convData.get('id')));
    // Parse sender safely 
    Map<String, Object> senderData = (Map<String, Object>) msgData.get('sender'); 
    String senderName = senderData != null ? String.valueOf(senderData.get('name')) : null; 
    
    // 🔎 Find or create parent conversation 
    String convExtId = String.valueOf(msgData.get('conversation_id')); 
    System.debug('ConvoId: ' + String.valueOf(msgData.get('conversation_id'))); 
    
    Id convId = null; 
    if (String.isNotBlank(convExtId)) { 
        List<Chatwoot_Conversation__c> convs = [ 
            SELECT Id, Chatwoot_ID__c 
            FROM Chatwoot_Conversation__c 
            WHERE Chatwoot_ID__c = :convExtId 
            LIMIT 1 
        ]; 
        
        if (!convs.isEmpty()) { 
            convId = convs[0].Id; 
        } else { 
            // ✅ fallback: auto-create conversation if missing 
            Chatwoot_Conversation__c newConv = new Chatwoot_Conversation__c( 
                Chatwoot_ID__c = convExtId, 
                Status__c = 'open' 
            ); 
            insert newConv; 
            convId = newConv.Id; 
            System.debug('Auto-created missing conversation with ID ' + convId); 
        } 
    } 
    
    // 📝 Create or update message 
    Chatwoot_Message__c msg = new Chatwoot_Message__c( 
        Chatwoot_ID__c = String.valueOf(convData.get('id')), 
        Content__c = String.valueOf(msgData.get('content')), 
        Sender_Type__c = String.valueOf(msgData.get('message_type')), 
        Sender_Name__c = senderName, 
        Chatwoot_Conversation__c = convId,
        Message_Id__c =String.valueOf(msgData.get('id'))
        /*CreatedAt__c = msgData.get('created_at') != null  
            ? DateTime.newInstanceGMT(((Long)msgData.get('created_at')) * 1000)  
            : null*/ 
    ); 
    
    System.debug('Upserting message: ' + msg); 
    insert msg; 
}


}