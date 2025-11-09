public with sharing class ChatwootService {
    // ------------ CONFIG - replace these with your real values ------------
    public static final String CHATWOOT_BASE_URL = 'https://app.chatwoot.com';
    public static final String ACCOUNT_ID = '135228';       // <-- replace
    public static final String INBOX_ID   = '80279';         // <-- replace
    public static final String API_TOKEN  = '9orcowU6bXFhNhAhZnQnsv8J';// <-- replace
    // ---------------------------------------------------------------------

    // Public: finds/creates contact+conversation then posts message
    public static void sendJobMessageByPhone(String rawPhone, String messageText) {
        if (String.isBlank(rawPhone)) {
            throw new AuraHandledException('Phone number required');
        }
        String phone = normalizePhone(rawPhone);
        try {
            Map<String, Object> contact = findOrCreateContact(phone);
            if (contact == null || !contact.containsKey('id')) {
                System.debug('ChatwootService: failed to find/create contact for ' + phone);
                return;
            }
            String contactId = String.valueOf(contact.get('id'));

            Map<String, Object> conversation = findOrCreateConversation(contactId);
            if (conversation == null || !conversation.containsKey('id')) {
                System.debug('ChatwootService: failed create/find conversation for contact ' + contactId);
                return;
            }
            String conversationId = String.valueOf(conversation.get('id'));

            postMessage(conversationId, messageText);
            System.debug('ChatwootService: message posted to conversation ' + conversationId);
        } catch (Exception ex) {
            // don't rethrow from async; log for debug
            System.debug('ChatwootService error: ' + ex.getMessage());
        }
    }

    // Normalize phone (strip non-digits). Adjust if you want +country prefix.
    private static String normalizePhone(String phone) {
        if (phone == null) return null;
        return phone.replaceAll('[^0-9\\+]', '');
    }

    // ----------------- HTTP helpers -----------------
    private static HttpResponse doGet(String url) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        setHeaders(req);
        Http http = new Http();
        return http.send(req);
    }

    private static HttpResponse doPost(String url, Object body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        setHeaders(req);
        if (body != null) req.setBody(JSON.serialize(body));
        Http http = new Http();
        return http.send(req);
    }

    private static void setHeaders(HttpRequest req) {
        // Add both api_access_token and Authorization Bearer to be resilient
        req.setHeader('api_access_token', API_TOKEN);
        req.setHeader('Authorization', 'Bearer ' + API_TOKEN);
        req.setHeader('Accept', 'application/json');
    }

    // ----------------- Contacts -----------------
    private static Map<String, Object> findContactByPhone(String phone) {
        String url = CHATWOOT_BASE_URL + '/api/v1/accounts/' + ACCOUNT_ID + '/contacts/search?q=' + EncodingUtil.urlEncode(phone, 'UTF-8');
        HttpResponse res = doGet(url);
        if (res == null) return null;
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            // Chatwoot returns { "payload": [...] } for search
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (parsed != null && parsed.containsKey('payload')) {
                List<Object> payload = (List<Object>) parsed.get('payload');
                if (!payload.isEmpty()) {
                    // return first match
                    return (Map<String, Object>) payload[0];
                }
            }
        } else {
            System.debug('Chatwoot findContactByPhone failed: ' + res.getStatusCode() + ' ' + res.getBody());
        }
        return null;
    }

    private static Map<String, Object> createContact(String phone) {
        String url = CHATWOOT_BASE_URL + '/api/v1/accounts/' + ACCOUNT_ID + '/contacts';
        Map<String, Object> body = new Map<String, Object>{
            'inbox_id' => INBOX_ID,
            'phone_number' => phone,
            'name' => 'Customer ' + phone
        };
        HttpResponse res = doPost(url, body);
        if (res != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            System.debug('Chatwoot createContact failed: ' + (res==null?'null':res.getStatusCode() + ' ' + res.getBody()));
        }
        return null;
    }

    private static Map<String, Object> findOrCreateContact(String phone) {
        Map<String, Object> contact = findContactByPhone(phone);
        if (contact == null) contact = createContact(phone);
        return contact;
    }

    // ----------------- Conversations -----------------
    private static Map<String, Object> findOrCreateConversation(String contactId) {
        // 1) list conversations for contact
        String listUrl = CHATWOOT_BASE_URL + '/api/v1/accounts/' + ACCOUNT_ID + '/contacts/' + contactId + '/conversations';
        HttpResponse listRes = doGet(listUrl);
        if (listRes != null && listRes.getStatusCode() >= 200 && listRes.getStatusCode() < 300) {
            // Chatwoot may return array of conversations
            Object parsed = JSON.deserializeUntyped(listRes.getBody());
            if (parsed instanceof List<Object>) {
                List<Object> convs = (List<Object>) parsed;
                if (!convs.isEmpty()) {
                    return (Map<String, Object>) convs[0];
                }
            } else if (parsed instanceof Map<String,Object>) {
                // in some versions returns object - handle defensively
                Map<String,Object> m = (Map<String,Object>) parsed;
                if (m.containsKey('payload')) {
                    List<Object> payload = (List<Object>) m.get('payload');
                    if (!payload.isEmpty()) return (Map<String, Object>) payload[0];
                }
            }
        }

        // 2) create conversation
        String createUrl = CHATWOOT_BASE_URL + '/api/v1/accounts/' + ACCOUNT_ID + '/conversations';
        Map<String, Object> body = new Map<String, Object>{
            'inbox_id' => INBOX_ID,
            'contact_id' => contactId
        };
        HttpResponse createRes = doPost(createUrl, body);
        if (createRes != null && (createRes.getStatusCode() == 200 || createRes.getStatusCode() == 201)) {
            return (Map<String, Object>) JSON.deserializeUntyped(createRes.getBody());
        } else {
            System.debug('Chatwoot createConversation failed: ' + (createRes==null?'null':createRes.getStatusCode() + ' ' + createRes.getBody()));
        }
        return null;
    }

    // ----------------- Messages -----------------
    private static void postMessage(String conversationId, String messageText) {
        String url = CHATWOOT_BASE_URL + '/api/v1/accounts/' + ACCOUNT_ID + '/conversations/' + conversationId + '/messages';
        Map<String,Object> body = new Map<String,Object>{
            'content' => messageText,
            'message_type' => 'outgoing'
        };
        HttpResponse res = doPost(url, body);
        if (res == null || !(res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
            System.debug('Chatwoot postMessage failed: ' + (res==null?'null':res.getStatusCode() + ' ' + res.getBody()));
        }
    }
}