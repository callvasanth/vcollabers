public with sharing class AppointmentCallNotifier {
    
    @InvocableMethod(label='Notify Appointment via Call')
    public static void notifyAppointments(List<Appointment__c> appointments) {
        // Loop through each Appointment and send async call
        for (Appointment__c appt : appointments) {
            if (appt.Contact__c != null) {
                sendAppointmentWebhookAsync(appt.Id);
            }
        }
    }

    @future(callout=true)
    public static void sendAppointmentWebhookAsync(Id appointmentId) {
        // Query appointment + related contact
        Appointment__c appt = [
            SELECT Id, Contact__r.Name, Contact__r.Phone,
                   Scheduled_Time_Start__c, Scheduled_Time_End__c,Language__c,Rating__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            LIMIT 1
        ];

        // Skip if no phone number
        if (String.isBlank(appt.Contact__r.Phone)) {
            System.debug('No phone found for appointment: ' + appt.Id);
            return;
        }

        // Prepare payload
        Map<String, Object> payload = new Map<String, Object>{
            'AppointmentId' => appt.Id,
            'CustomerName' => appt.Contact__r.Name,
            'CustomerPhone' => appt.Contact__r.Phone,
            'AppointmentDate' => appt.Scheduled_Time_Start__c,
            'AppointmentEnd' => appt.Scheduled_Time_End__c,
             'Language' =>  appt.Language__c,
                'Rating'  => appt.Rating__c
            //'Address' => appt.Address__c
        };

        // Create HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://aiorchestrator.vcollabetiq.com/webhook/e0606e1f-0d08-4b31-a5c2-3fc648c635d2'); // replace with your real webhook URL
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('Webhook response: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Error sending webhook: ' + e.getMessage());
        }
    }
}