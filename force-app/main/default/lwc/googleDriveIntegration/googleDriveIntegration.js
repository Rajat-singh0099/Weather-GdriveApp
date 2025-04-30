import { LightningElement, track } from 'lwc';
import getCredentials from '@salesforce/apex/GoogleDriveAuthController.getCredentials';
import refreshAccessToken from '@salesforce/apex/GoogleDriveAuthController.refreshAccessToken';
import initiateResumableUpload from '@salesforce/apex/GoogleDriveController.initiateResumableUpload';
import uploadFileContent from '@salesforce/apex/GoogleDriveController.uploadFileContent';
import fetchFileContent from '@salesforce/apex/GoogleDriveController.fetchFileContent';
import listFiles from '@salesforce/apex/GoogleDriveController.listFiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createFolder from '@salesforce/apex/GoogleDriveController.createFolder';

export default class GoogleDriveIntegration extends LightningElement {
    @track isAuthenticated = false;
    @track files = [];
    @track folderName = '';
    @track isLoading = false;
    accessToken;
    @track isUploading = false;
    @track uploadProgress = 0;
    @track currentFolderId = 'root';
    @track folderHistory = [];

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
            const rawFiles = await listFiles({
                accessToken: this.accessToken,
                parentFolderId: this.currentFolderId
            });
            this.setFiles(rawFiles.map(file => ({
                id: file.id,
                name: file.name,
                mimeType: file.mimeType,
                iconName: file.mimeType === 'application/vnd.google-apps.folder' ? 'utility:open_folder' : 'utility:file'
            })));
        } catch (error) {
            this.showToast('Error', 'Failed to load files', 'error');
        }
    }    

    handleFolderClick(event) {
        const folderId = event.target.dataset.id;
        if (folderId) {
            this.folderHistory.push(this.currentFolderId); // Save current before moving
            this.currentFolderId = folderId;
            this.loadFiles();
        }
    }    

    handleGoBack() {
        if (this.folderHistory.length > 0) {
            this.currentFolderId = this.folderHistory.pop(); // Go to previous folder
            this.loadFiles();
        }
    }    

    handleFileClick(event) {
        const fileId = event.target.dataset.id;
        if (fileId) {
            const fileUrl = `https://drive.google.com/file/d/${fileId}/view`;
            window.open(fileUrl, '_blank');
        }
    }
    

    handleFolderNameChange(event) {
        this.folderName = event.target.value;
    }
    
    async handleCreateFolder() {
        this.isLoading = true;
        try {
            console.log('Creating folder with name:', this.folderName);
            console.log('Access token:', this.accessToken);

            const folderId = await createFolder({
                accessToken: this.accessToken,
                folderName: this.folderName
            });

            console.log('Folder created successfully with ID:', folderId);
            this.showToast('Success', 'Folder created successfully', 'success');
            this.folderName = '';
            await this.loadFiles();
        } catch (error) {
            console.error('Folder creation failed:', error);
            this.showToast('Error', 'Failed to create folder', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    setFiles(files) {
        this.files = files.map(file => ({
            ...file,
            isFolder: this.isFolder(file.mimeType),
        }));
    }

    isFolder(mimeType) {
        return mimeType === 'application/vnd.google-apps.folder';
    }    

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get isCreateFolderDisabled() {
        return this.isLoading || !this.folderName || this.folderName.trim() === '';
    }
    
}
