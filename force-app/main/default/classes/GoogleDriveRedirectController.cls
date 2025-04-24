public with sharing class GoogleDriveRedirectController {
    public String code { get; set; }

    public PageReference redirectToLWC() {
        // Store code in a temporary URL fragment
        String navItem = '/lightning/n/Google_Drive#code=' + code;
        PageReference pageRef = new PageReference(navItem);
        pageRef.setRedirect(true);
        return pageRef;
    }
}
