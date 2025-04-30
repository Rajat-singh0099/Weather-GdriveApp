public with sharing class GoogleDriveController {
    private static final String DRIVE_API = 'https://www.googleapis.com/drive/v3';

    @AuraEnabled
    public static List<Map<String, Object>> listFiles(String accessToken, String parentFolderId) {
        if (String.isBlank(parentFolderId)) {
            parentFolderId = 'root';
        }
    
        // Build the raw query
        String rawQuery = '\'' + parentFolderId + '\' in parents and trashed=false';
        String encodedQuery = EncodingUtil.urlEncode(rawQuery, 'UTF-8');
    
        HttpRequest req = new HttpRequest();
        req.setEndpoint(DRIVE_API + '/files?q=' + encodedQuery + '&fields=files(id,name,mimeType,parents)');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
    
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> rawFiles = (List<Object>) result.get('files');
            List<Map<String, Object>> files = new List<Map<String, Object>>();
            for (Object rawFile : rawFiles) {
                files.add((Map<String, Object>) rawFile);
            }
            return files;
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

        System.debug('Create Folder Request: ' + req);

        HttpResponse res = http.send(req);
        System.debug('Create Folder Response: Status=' + res.getStatusCode() + ', Body=' + res.getBody());

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('id');
        } else {
            throw new AuraHandledException('Failed to create folder: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String initiateResumableUpload(String accessToken, String fileName, String mimeType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json; charset=UTF-8');
        req.setHeader('X-Upload-Content-Type', mimeType);

        Map<String, Object> metadata = new Map<String, Object>{
            'name' => fileName,
            'mimeType' => mimeType
        };
        req.setBody(JSON.serialize(metadata));

        HttpResponse res = new Http().send(req);
        System.debug('Initiate Upload Response: ' + res.getBody());

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return res.getHeader('Location'); // Upload URL for PUT request
        } else {
            throw new AuraHandledException('Failed to initiate resumable upload: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String uploadFileContent(String uploadUrl, String fileContentBase64) {
        Blob fileBlob = EncodingUtil.base64Decode(fileContentBase64);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(uploadUrl);
        req.setMethod('PUT');
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setHeader('Content-Length', String.valueOf(fileBlob.size()));
        req.setBodyAsBlob(fileBlob);

        HttpResponse res = new Http().send(req);
        System.debug('Upload File Content Response: ' + res.getBody());

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return res.getBody();
        } else {
            throw new AuraHandledException('Failed to upload file content: ' + res.getBody());
        }
    }

    @AuraEnabled
    public static String fetchFileContent(String documentId) {
        try {
            ContentVersion cv = [
                SELECT VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :documentId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return EncodingUtil.base64Encode(cv.VersionData);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch file content: ' + e.getMessage());
        }
    }
}
