public with sharing class GoogleDriveController {
    private static final String DRIVE_API = 'https://www.googleapis.com/drive/v3';

    @AuraEnabled
    public static List<Map<String, Object>> listFiles(String accessToken) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(DRIVE_API + '/files?q=\'root\'+in+parents&fields=files(id,name,mimeType)');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (List<Map<String, Object>>) result.get('files');
        } else {
            throw new AuraHandledException('Failed to list files: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String createFolder(String accessToken, String folderName) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(DRIVE_API + '/files');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        String body = JSON.serialize(new Map<String, Object>{
            'name' => folderName,
            'mimeType' => 'application/vnd.google-apps.folder'
        });
        req.setBody(body);

        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('id');
        } else {
            throw new AuraHandledException('Failed to create folder: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String uploadFile(String accessToken, String fileName, String fileContent) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=media');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setBodyAsBlob(EncodingUtil.base64Decode(fileContent));

        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('id');
        } else {
            throw new AuraHandledException('Failed to upload file: ' + res.getBody());
        }
    }
}