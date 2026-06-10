public class BankingOTPService {
    
    // Wrapper class for Flow input parameters
    public class OTPRequest {
        @InvocableVariable(label='Operation Type' description='Operation to perform: GENERATE, VERIFY, or CHECK_VERIFIED' required=true)
        public String operationType;
        
        @InvocableVariable(label='Account Number' description='Bank account number (required for GENERATE operation)')
        public String accountNumber;
        
        @InvocableVariable(label='Account ID' description='Bank account record ID (required for VERIFY and CHECK_VERIFIED operations)')
        public String accountId;
        
        @InvocableVariable(label='Entered OTP' description='OTP code entered by user (required for VERIFY operation)')
        public String enteredOTP;
    }
    
    // Wrapper class for Flow output
    public class OTPResponse {
        @InvocableVariable(label='Success' description='True if operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Message' description='Result message')
        public String message;
        
        @InvocableVariable(label='OTP Code' description='Generated OTP code (only for testing)')
        public String otpCode;
        
        @InvocableVariable(label='Is Verified' description='True if account is verified (CHECK_VERIFIED operation)')
        public Boolean isVerified;
        
        @InvocableVariable(label='Account ID' description='Account record ID (GENERATE operation)')
        public String accountId;
        
        @InvocableVariable(label='Session Token')
   		public String sessionToken;
    }
    
    // Single invocable method for Flow
    @InvocableMethod(label='Banking OTP Operations' description='Perform OTP operations: Generate, Verify, or Check Verification Status')
    public static List<OTPResponse> performOTPOperation(List<OTPRequest> requests) {
        System.debug('calling From Agent');
        List<OTPResponse> responses = new List<OTPResponse>();
        
        for (OTPRequest request : requests) {
            OTPResponse response = new OTPResponse();
            
            //try {
                switch on request.operationType.toUpperCase() {
                    when 'GENERATE' {
                        System.debug('Generating OTP');
                        if (String.isBlank(request.accountNumber)) {
                            response.success = false;
                            response.message = 'Account Number is required for GENERATE operation';
                        } else {
                            OTPResult result = generateAndSendOTP(request.accountNumber);
                            response.success = result.success;
                            response.message = result.message;
                            response.otpCode = result.otpCode;
                            response.accountId = result.accountId;
                        }
                    }
                    when 'VERIFY' {
                        System.debug('verifying otp');
                        if (String.isBlank(request.accountId) || String.isBlank(request.enteredOTP)) {
                            response.success = false;
                            response.message = 'Account ID and Entered OTP are required for VERIFY operation';
                        } else {
                            OTPResult result = verifyOTP(request.accountId, request.enteredOTP);
                            response.success = result.success;
                            response.message = result.message;
                            response.sessionToken = result.sessionToken;
                        }
                    }
                    when 'CHECK_VERIFIED' {
                        if (String.isBlank(request.accountId)) {
                            response.success = false;
                            response.message = 'Account ID is required for CHECK_VERIFIED operation';
                        } else {
                            Boolean verified = isVerified(request.accountId);//return true or false
                            System.debug('verified--'+verified);
                            response.success = true;
                            response.isVerified = verified;
                            response.message = verified ? 'Account is verified' : 'Account is not verified or session expired';
                        }
                    }
                    when else {
                        response.success = false;
                        response.message = 'Invalid operation type. Use GENERATE, VERIFY, or CHECK_VERIFIED';
                    }
                }
            //} catch (Exception e) {
                //response.success = false;
               // response.message = 'System error: ' + e.getMessage();
                //System.debug('OTP Operation Error: ' + e.getMessage());
            //}
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // Internal result class (not visible to Flow)
    private class OTPResult {
        public Boolean success;
        public String message;
        public String otpCode;
        public String accountId;
        public String sessionToken;
        
        public OTPResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    // Generate and send OTP
    private static OTPResult generateAndSendOTP(String accountNumber) {
    System.debug('calling From Agent');
    OTPResult result;
    RS_Bank_Account__c account;

    try {
        account = [
            SELECT Id, Account_Number__c, Customer_Email__c, Last_OTP_Request__c, Account_Holder__c
            FROM RS_Bank_Account__c 
            WHERE Account_Number__c = :accountNumber 
            LIMIT 1
        ];
        
        // Check rate limiting (1 OTP per minute)
        if (account.Last_OTP_Request__c != null && 
            account.Last_OTP_Request__c.addMinutes(1) > DateTime.now()) {
            return new OTPResult(false, 'Please wait before requesting another OTP');
        }
        
        // Generate 6-digit OTP
        String otpCode = generateOTPCode();
        
        // Update account with OTP details
        account.OTP_Code__c = otpCode;
        account.OTP_Expiry__c = DateTime.now().addMinutes(5);
        account.OTP_Verified__c = false;
        account.Last_OTP_Request__c = DateTime.now();
        account.OTP_Attempts__c = 0;
        
        update account;
        
        // Send email
        Boolean emailSent = sendOTPEmail(account);
        
        if (emailSent) {
            result = new OTPResult(true, 'OTP sent to your registered email');
            result.otpCode = otpCode; // For testing only, remove in production
            result.accountId = account.Id;
        } else {
            return new OTPResult(false, 'Failed to send OTP email');
        }
        
    } catch (QueryException e) {
        System.debug('Account not found: ' + e.getMessage());
        return new OTPResult(false, 'Account not found');
    } catch (Exception e) {
        System.debug('OTP Generation Error: ' + e.getMessage());
        return new OTPResult(false, 'System error. Please try again');
    }

    // 🔹 Add Session Token after OTP is generated successfully
    if (result != null && result.success) {
        String sessionToken = generateSessionToken();
        account.Session_Token__c = sessionToken;
        account.Session_Expiry__c = DateTime.now().addMinutes(30);
        update account;

        result.sessionToken = sessionToken;
    }

    return result;
}


    
    // Verify OTP
    private static OTPResult verifyOTP(String accountId, String enteredOTP) {
       // try {
            RS_Bank_Account__c account = [
                SELECT Id, Account_Number__c, OTP_Code__c, OTP_Expiry__c, OTP_Attempts__c, OTP_Verified__c,
                   Session_Token__c, Session_Expiry__c
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountId 
                LIMIT 1
            ];
            
            // Check if already verified
            if (account.OTP_Verified__c) {
                return new OTPResult(true, 'Already verified');
            }
            
            // Check expiry
            if (account.OTP_Expiry__c == null || account.OTP_Expiry__c < DateTime.now()) {
                return new OTPResult(false, 'OTP has expired. Please request a new one');
            }
            
            // Check attempts // Too many attempts
            if (account.OTP_Attempts__c >= 3) {
                return new OTPResult(false, 'Too many failed attempts. Please request a new OTP');
            }
            
            // Verify OTP
            if (account.OTP_Code__c != null && account.OTP_Code__c.equals(enteredOTP)) {
                System.debug('enteredOTP--'+enteredOTP);
                System.debug('account.OTP_Code__c--'+account.OTP_Code__c);
                System.debug('line 189');
                // Success - mark as verified
                account.OTP_Verified__c = true;
                account.OTP_Code__c = null; // Clear OTP for security
                // Generate new session token on successful verification
            	String newSessionToken = generateSessionToken();
            	account.Session_Token__c = newSessionToken;
            	account.Session_Expiry__c = DateTime.now().addMinutes(30);
                update account;
                
                OTPResult result = new OTPResult(true, 'OTP verified successfully');
            	result.sessionToken = newSessionToken; // Return to Flow
            	return result;
                
            } else {
                // Failed attempt
                account.OTP_Attempts__c = (account.OTP_Attempts__c == null ? 1 : account.OTP_Attempts__c + 1);
                update account;
                
                return new OTPResult(false, 'Invalid OTP. Attempts remaining: ' + (3 - account.OTP_Attempts__c));
            }
            
        //} catch (Exception e) {
            //System.debug('OTP Verification Error: ' + e.getMessage());
            //return new OTPResult(false, 'System error. Please try again');
        //}
    }
    
    // Check if user is verified
    private static Boolean isVerified(String accountId) {
        System.debug('inside isVerified');
        try {
            RS_Bank_Account__c account = [
                SELECT OTP_Verified__c, OTP_Expiry__c, Session_Expiry__c
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountId 
                LIMIT 1
            ];
            
            // Check if verified and not expired (session valid for 30 minutes)
            return account.OTP_Verified__c && 
               account.Session_Expiry__c != null &&
               account.Session_Expiry__c > DateTime.now();
                   
        } catch (Exception e) {
            return false;
        }
    }
    
    // Generate random 6-digit OTP
    private static String generateOTPCode() {
        //Integer min = 100000;
        //Integer max = 999999;
        //Integer randomNum = min + (Math.random() * (max - min + 1)).intValue();
        //return String.valueOf(randomNum);
        String otp = '112233';
        return otp;
    }
    
    // Send OTP email
    private static Boolean sendOTPEmail(RS_Bank_Account__c account) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{account.Customer_Email__c});
            email.setSubject('Your Banking Verification Code');
            
            String htmlBody = '<html><body style="font-family: Arial, sans-serif;">' +
                '<h2 style="color: #1f4788;">Banking Verification Code</h2>' +
                '<p>Dear ' + account.Account_Holder__c + ',</p>' +
                '<p>Your verification code for banking inquiry is:</p>' +
                '<div style="background-color: #f0f0f0; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; color: #1f4788; margin: 20px 0;">' +
                account.OTP_Code__c + '</div>' +
                '<p><strong>Important:</strong></p>' +
                '<ul>' +
                '<li>This code will expire in 5 minutes</li>' +
                '<li>Please do not share this code with anyone</li>' +
                '<li>This code can only be used once</li>' +
                '</ul>' +
                '<p>If you did not request this code, please contact us immediately.</p>' +
                '<br><p>Best regards,<br>Your Banking Team</p>' +
                '</body></html>';
            
            email.setHtmlBody(htmlBody);
            email.setSaveAsActivity(false);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            
            return results[0].isSuccess();
            
        } catch (Exception e) {
            System.debug('Email sending error: ' + e.getMessage());
            return false;
        }
    }
    // NEW METHOD: Session validation used by BankingQueryService
    public static Boolean isSessionValid(String accountNumber, String sessionToken) {
        System.debug('inside isSessionValid - Account: ' + accountNumber + ', Token: ' + sessionToken);
        try {
            // If no session token provided, return false
            if (String.isBlank(sessionToken)) {
                System.debug('No session token provided');
                return false;
            }
            
            RS_Bank_Account__c account = [
                SELECT OTP_Verified__c, Session_Token__c, Session_Expiry__c
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            
            // Check if verified, token matches, and session not expired
            Boolean isValid = account.OTP_Verified__c && 
                             account.Session_Token__c != null &&
                             account.Session_Token__c.equals(sessionToken) &&
                             account.Session_Expiry__c != null && 
                             account.Session_Expiry__c > DateTime.now();
            
            System.debug('Session validation result: ' + isValid);
            return isValid;
                   
        } catch (Exception e) {
            System.debug('Session validation error: ' + e.getMessage());
            return false;
        }
    }
    // Generate session token
    private static String generateSessionToken() {
        return 'S_' +
    EncodingUtil.base64Encode(Crypto.generateAesKey(128)).substring(0, 8) +
    '_' +
    String.valueOf(System.now().getTime()).right(4);

    }
}