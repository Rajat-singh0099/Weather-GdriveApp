import { LightningElement, track } from 'lwc';
import getCredentials from '@salesforce/apex/GoogleDriveAuthController.getCredentials';
import refreshAccessToken from '@salesforce/apex/GoogleDriveAuthController.refreshAccessToken';
import initiateResumableUpload from '@salesforce/apex/GoogleDriveController.initiateResumableUpload';
import uploadFileContent from '@salesforce/apex/GoogleDriveController.uploadFileContent';
import fetchFileContent from '@salesforce/apex/GoogleDriveController.fetchFileContent';
import listFiles from '@salesforce/apex/GoogleDriveController.listFiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GoogleDriveIntegration extends LightningElement {
    @track isAuthenticated = false;
    @track files = [];
    @track folderName = '';
    @track isLoading = false;
    accessToken;

    connectedCallback() {
        this.isLoading = true;
        this.checkAuthentication();
    }

    async checkAuthentication() {
        try {
            const creds = await getCredentials();
            if (creds?.Access_Token__c) {
                const expired = Date.now() > new Date(creds.Token_Expiry__c).getTime();
                this.accessToken = expired
                    ? await refreshAccessToken({ refreshToken: creds.Refresh_Token__c })
                    : creds.Access_Token__c;
                this.isAuthenticated = true;
                await this.loadFiles();
            } else {
                this.isAuthenticated = false;
            }
        } catch (error) {
            this.showToast('Error', 'Authentication check failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFinished(event) {
        this.isLoading = true;
        try {
            for (const file of event.detail.files) {
                const base64Content = await this.readFileBase64(file.documentId);
                const mimeType = file.type || 'application/octet-stream';

                // Step 1: Start resumable upload
                const uploadUrl = await initiateResumableUpload({
                    accessToken: this.accessToken,
                    fileName: file.name,
                    mimeType: mimeType
                });

                // Step 2: Upload file content
                await uploadFileContent({
                    uploadUrl: uploadUrl,
                    fileContentBase64: base64Content
                });

                this.showToast('Success', `${file.name} uploaded to Google Drive`, 'success');
            }
            await this.loadFiles();
        } catch (error) {
            console.error('File upload failed', error);
            this.showToast('Error', error.body?.message || 'File upload failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async readFileBase64(documentId) {
        try {
            return await fetchFileContent({ documentId });
        } catch (error) {
            console.error('Error fetching file content:', error);
            throw error;
        }
    }

    async loadFiles() {
        try {
            const rawFiles = await listFiles({ accessToken: this.accessToken });
            this.files = rawFiles.map(file => ({
                id: file.id,
                name: file.name,
                mimeType: file.mimeType,
                iconName: file.mimeType === 'application/vnd.google-apps.folder' ? 'utility:open_folder' : 'utility:file'
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load files', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
