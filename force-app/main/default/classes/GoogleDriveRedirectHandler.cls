public with sharing class GoogleDriveRedirectHandler {
    public PageReference processCode() {
        String code = ApexPages.currentPage().getParameters().get('code');
        if (String.isNotBlank(code)) {
            try {
                GoogleDriveAuthController.handleCallback(code);
            } catch (Exception e) {
                System.debug('Error in OAuth callback handling: ' + e.getMessage());
            }
        }
        // Redirect to Lightning page
        PageReference redirect = new PageReference('/lightning/n/Google_Drive');
        redirect.setRedirect(true);
        return redirect;
    }
}
