import java.net.URI;
import java.util.Calendar;
import java.util.Date;

import com.couchbase.lite.*;

public class LiteServer {
    public static void main(String[] args) throws Exception {
        CouchbaseLite.init();
        Database db = new Database("lite-server");

        // If a Sync Gateway URL is provided, start replicator
        String sgURL = (args.length > 0 ? args[0] : null);
        if (sgURL != null) {
            Endpoint endpoint = new URLEndpoint(new URI(sgURL));
            ReplicatorConfiguration config = new ReplicatorConfiguration(db, endpoint)
                .setReplicatorType(ReplicatorConfiguration.ReplicatorType.PUSH_AND_PULL)
                .setContinuous(true);

            // If a username/password are provided, set the authenticator
            String username = (args.length > 1 ? args[1] : null);
            String password = (args.length > 2 ? args[2] : null);
            if (username != null && password != null) {
                config.setAuthenticator(new BasicAuthenticator(username, password.toCharArray()));
            }
            
            Replicator replicator = new Replicator(config);

            replicator.start();
        } else {
            System.out.println("Sync Gateway URL is null. Replicator was not started.");
        }

        new Server(
            new Server.Getter() {
                public String get(String id) {
                    Document doc = db.getDocument(id);

                    if (doc != null) {
                        return JSONUtils.json(doc.toMap());
                    }
                    
                    return null;
                }
            }, new Server.Setter() {
                public void set(String id, String json) {
                    try {
                        db.save(new MutableDocument(id, JSONUtils.map(json)));
                    } catch (CouchbaseLiteException e) {
                        throw new RuntimeException("Error saving document", e);
                    }
                }
            }, new Server.Results() {
                public void set(String results) {
                    try {
                        Date date = new Date();
                        Calendar calendar = Calendar.getInstance();
                        calendar.setTime(date);
                        int year = calendar.get(Calendar.YEAR);

                        MutableDocument doc = new MutableDocument("results");
                        doc.setString("copyright", "Copyright (c) " + year + " Couchbase, Inc All rights reserved.");
                        doc.setDate("date", new Date());
                        doc.setString("results", results);

                        db.save(doc);
                    } catch (CouchbaseLiteException e) {
                        throw new RuntimeException("Error saving results", e);
                    }
                }

                public String get() {
                    Document doc = db.getDocument("results");

                    if (doc != null) {
                        return doc.getString("copyright").toString() + "\n" +
                               doc.getDate("date").toString() + "\n\n" +
                               doc.getString("results");
                    }
                    
                    return null;
                }
            }
        );
    }
}