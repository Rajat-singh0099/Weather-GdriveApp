public with sharing class GoogleDriveAuthController {
    private static Google_Drive_Settings__mdt getSettings() {
        return [
            SELECT Client_ID__c, Client_Secret__c, Redirect_URI__c 
            FROM Google_Drive_Settings__mdt 
            WHERE DeveloperName = 'Default_Settings' LIMIT 1
        ];
    }

    @AuraEnabled
    public static String getAuthUrl() {
        Google_Drive_Settings__mdt s = getSettings();
        return 'https://accounts.google.com/o/oauth2/v2/auth?' +
               'client_id=' + s.Client_ID__c +
               '&redirect_uri=' + EncodingUtil.urlEncode(s.Redirect_URI__c, 'UTF-8') +
               '&response_type=code' +
               '&scope=https://www.googleapis.com/auth/drive' +
               '&access_type=offline&prompt=consent';
    }
    
    @AuraEnabled
    public static void handleCallback(String code) {
        Google_Drive_Settings__mdt s = getSettings();

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(
            'code=' + EncodingUtil.urlEncode(code, 'UTF-8') +
            '&client_id=' + s.Client_ID__c +
            '&client_secret=' + s.Client_Secret__c +
            '&redirect_uri=' + EncodingUtil.urlEncode(s.Redirect_URI__c, 'UTF-8') +
            '&grant_type=authorization_code'
        );

        HttpResponse res = new Http().send(req);
        System.debug('Token Exchange Response: Status=' + res.getStatusCode() + ', Body=' + res.getBody());

        if (res.getStatusCode() == 200) {
            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String accessToken = (String) json.get('access_token');
            String refreshToken = (String) json.get('refresh_token');
            Integer expiresIn = (Integer) json.get('expires_in');

            System.debug('Access Token Length: ' + (accessToken != null ? accessToken.length() : 0));
            System.debug('Refresh Token Length: ' + (refreshToken != null ? refreshToken.length() : 0));

            Google_Drive_Credential__c cred;
            List<Google_Drive_Credential__c> existing = [
                SELECT Id FROM Google_Drive_Credential__c WHERE User__c = :UserInfo.getUserId() LIMIT 1
            ];

            if (existing.isEmpty()) {
                cred = new Google_Drive_Credential__c(User__c = UserInfo.getUserId());
                insert cred;
            } else {
                cred = existing[0];
            }

            cred.Access_Token__c = accessToken;
            cred.Refresh_Token__c = refreshToken;
            cred.Token_Expiry__c = DateTime.now().addSeconds(expiresIn);
            cred.Google_Account_Email__c = UserInfo.getUserEmail();

            try {
                update cred;
                System.debug('Credentials updated successfully for User: ' + UserInfo.getUserId());
            } catch (DmlException e) {
                System.debug('DML Error: ' + e.getMessage());
                throw new AuraHandledException('Failed to save credentials: ' + e.getMessage());
            }
        } else {
            throw new AuraHandledException('Failed to exchange code: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String refreshAccessToken(String refreshToken) {
        Google_Drive_Settings__mdt s = getSettings();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('client_id=' + s.Client_ID__c +
                    '&client_secret=' + s.Client_Secret__c +
                    '&refresh_token=' + refreshToken +
                    '&grant_type=refresh_token');

        HttpResponse res = new Http().send(req);
        System.debug('Token Refresh Response: Status=' + res.getStatusCode() + ', Body=' + res.getBody());

        if (res.getStatusCode() == 200) {
            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String accessToken = (String) json.get('access_token');
            System.debug('New Access Token Length: ' + (accessToken != null ? accessToken.length() : 0));

            Google_Drive_Credential__c cred = [
                SELECT Id FROM Google_Drive_Credential__c WHERE User__c = :UserInfo.getUserId() LIMIT 1
            ];
            cred.Access_Token__c = accessToken;
            cred.Token_Expiry__c = DateTime.now().addSeconds((Integer) json.get('expires_in'));

            try {
                update cred;
                return cred.Access_Token__c;
            } catch (DmlException e) {
                System.debug('DML Error: ' + e.getMessage());
                throw new AuraHandledException('Failed to save refreshed token: ' + e.getMessage());
            }
        } else {
            throw new AuraHandledException('Token refresh failed: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static Google_Drive_Credential__c getCredentials() {
        List<Google_Drive_Credential__c> creds = [
            SELECT Access_Token__c, Refresh_Token__c, Token_Expiry__c
            FROM Google_Drive_Credential__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        return creds.isEmpty() ? null : creds[0];
    }
}