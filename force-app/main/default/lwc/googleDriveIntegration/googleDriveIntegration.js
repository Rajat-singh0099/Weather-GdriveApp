import { LightningElement, track } from 'lwc';
import getAuthUrl from '@salesforce/apex/GoogleDriveAuthController.getAuthUrl';
import getCredentials from '@salesforce/apex/GoogleDriveAuthController.getCredentials';
import refreshAccessToken from '@salesforce/apex/GoogleDriveAuthController.refreshAccessToken';
import handleCallback from '@salesforce/apex/GoogleDriveAuthController.handleCallback';
import listFiles from '@salesforce/apex/GoogleDriveController.listFiles';
import createFolder from '@salesforce/apex/GoogleDriveController.createFolder';
import uploadFile from '@salesforce/apex/GoogleDriveController.uploadFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GoogleDriveIntegration extends LightningElement {
    @track isAuthenticated = false;
    @track files = [];
    @track folderName = '';
    @track isLoading = false;
    accessToken;

    connectedCallback() {
        this.isLoading = true;
        try {
            const hashParams = new URLSearchParams(window.location.hash.substring(1));
            const code = hashParams.get('code');

            // Clear URL hash to prevent reuse
            if (code) {
                history.replaceState(null, null, window.location.pathname);
            }

            // Process code only if not already used
            const processedCode = sessionStorage.getItem('processedCode');
            if (code && processedCode !== code) {
                this.processAuthCode(code);
                sessionStorage.setItem('processedCode', code);
            } else {
                this.checkAuthentication();
            }
        } catch (error) {
            this.showToast('Error', 'Initialization failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async processAuthCode(code) {
        this.isLoading = true;
        try {
            await handleCallback({ code });
            this.isAuthenticated = true;
            this.showToast('Success', 'Google Drive connected', 'success');
            await this.checkAuthentication();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'OAuth failed', 'error');
            sessionStorage.removeItem('processedCode'); // Allow retry
        } finally {
            this.isLoading = false;
        }
    }

    async checkAuthentication() {
        this.isLoading = true;
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
            this.showToast('Error', 'Auth check failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleConnect() {
        this.isLoading = true;
        try {
            sessionStorage.removeItem('processedCode'); // Clear for new flow
            const url = await getAuthUrl();
            window.location.href = url;
        } catch (error) {
            this.showToast('Error', 'Failed to connect', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadFiles() {
        this.isLoading = true;
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
        } finally {
            this.isLoading = false;
        }
    }

    handleFolderNameChange(event) {
        this.folderName = event.target.value;
    }

    async handleCreateFolder() {
        this.isLoading = true;
        try {
            await createFolder({ accessToken: this.accessToken, folderName: this.folderName });
            this.showToast('Success', 'Folder created', 'success');
            this.folderName = '';
            await this.loadFiles();
        } catch (error) {
            this.showToast('Error', 'Folder creation failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFinished(event) {
        this.isLoading = true;
        try {
            for (const file of event.detail.files) {
                const content = await this.readFile(file.documentId);
                await uploadFile({
                    accessToken: this.accessToken,
                    fileName: file.name,
                    fileContent: content
                });
                this.showToast('Success', `${file.name} uploaded`, 'success');
            }
            await this.loadFiles();
        } catch (error) {
            this.showToast('Error', 'File upload failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async readFile(documentId) {
        const res = await fetch(`/sfc/servlet.shepherd/document/download/${documentId}`);
        const blob = await res.blob();
        return new Promise(resolve => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result.split(',')[1]);
            reader.readAsDataURL(blob);
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}