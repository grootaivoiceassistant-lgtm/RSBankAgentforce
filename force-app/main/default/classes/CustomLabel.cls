// Execute this in Developer Console > Debug > Open Execute Anonymous Window

// Method 1: Create Spanish User Directly
public class CustomLabel{
public static User createSpanishUser() {
    // Get a standard profile
    Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Identity User' LIMIT 1];
    
    // Create the user
    User spanishUser = new User();
    spanishUser.FirstName = 'Maria';
    spanishUser.LastName = 'Garcia';
    spanishUser.Email = 'maria.garcia@testcompany.com';
    spanishUser.Username = 'maria.garcia@testcompany.com.dev' + System.currentTimeMillis(); // Make unique
    spanishUser.Alias = 'mgarcia';
    spanishUser.TimeZoneSidKey = 'Europe/Madrid';
    spanishUser.LocaleSidKey = 'es_ES'; // Spanish (Spain)
    spanishUser.LanguageLocaleKey = 'es'; // Spanish Language
    spanishUser.EmailEncodingKey = 'UTF-8';
    spanishUser.ProfileId = standardProfile.Id;
    spanishUser.IsActive = true;
    
    // Insert user
    try {
        insert spanishUser;
        System.debug('Spanish user created successfully: ' + spanishUser.Username);
        return spanishUser;
    } catch (Exception e) {
        System.debug('Error creating Spanish user: ' + e.getMessage());
        return null;
    }
}

// Method 2: Bulk Create Multiple Language Users
public static List<User> createMultiLanguageUsers() {
    Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Identity User' LIMIT 1];
    
    List<User> usersToInsert = new List<User>();
    
    // Spanish User
    User spanishUser = new User(
        FirstName = 'Carlos',
        LastName = 'Rodriguez',
        Email = 'carlos.rodriguez@testcompany.com',
        Username = 'carlos.rodriguez@testcompany.com.dev' + System.currentTimeMillis(),
        Alias = 'crodrig',
        TimeZoneSidKey = 'America/Mexico_City',
        LocaleSidKey = 'es_MX', // Spanish (Mexico)
        LanguageLocaleKey = 'es',
        EmailEncodingKey = 'UTF-8',
        ProfileId = standardProfile.Id,
        IsActive = true
    );
    usersToInsert.add(spanishUser);
    
    // French User
    User frenchUser = new User(
        FirstName = 'Jean',
        LastName = 'Dupont',
        Email = 'jean.dupont@testcompany.com',
        Username = 'jean.dupont@testcompany.com.dev' + System.currentTimeMillis(),
        Alias = 'jdupont',
        TimeZoneSidKey = 'Europe/Paris',
        LocaleSidKey = 'fr_FR', // French (France)
        LanguageLocaleKey = 'fr',
        EmailEncodingKey = 'UTF-8',
        ProfileId = standardProfile.Id,
        IsActive = true
    );
    usersToInsert.add(frenchUser);
    
    // German User
    User germanUser = new User(
        FirstName = 'Hans',
        LastName = 'Mueller',
        Email = 'hans.mueller@testcompany.com',
        Username = 'hans.mueller@testcompany.com.dev' + System.currentTimeMillis(),
        Alias = 'hmueller',
        TimeZoneSidKey = 'Europe/Berlin',
        LocaleSidKey = 'de_DE', // German (Germany)
        LanguageLocaleKey = 'de',
        EmailEncodingKey = 'UTF-8',
        ProfileId = standardProfile.Id,
        IsActive = true
    );
    usersToInsert.add(germanUser);
    
    try {
        insert usersToInsert;
        System.debug('Multi-language users created successfully:');
        for (User u : usersToInsert) {
            System.debug('- ' + u.FirstName + ' ' + u.LastName + ' (' + u.LanguageLocaleKey + ')');
        }
        return usersToInsert;
    } catch (Exception e) {
        System.debug('Error creating multi-language users: ' + e.getMessage());
        return null;
    }
}
}