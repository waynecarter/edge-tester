import java.net.*;
import java.io.*;

public class Server {
    private static final int PORT = 8080;
    
    private static final String NEW_LINE = "\r\n";

    public interface Getter {
        // Request path format: http://localhost:8080/get?id=abc123
        // Response body: JSON string
        String get(String id);
    }

    public interface Setter {
        // Request path format: http://localhost:8080/set?id=abc123&json={name=%22John%20Doe%22}
        // Response body: null
        void set(String id, String json);
    }

    public void run(Getter getter, Setter setter) {
        ServerSocket socket = null;
        
        try {
            socket = new ServerSocket(PORT);

            while (true) {
                Socket connection = socket.accept();

                BufferedReader in = new BufferedReader(new InputStreamReader(connection.getInputStream()));
                OutputStream out = new BufferedOutputStream(connection.getOutputStream());
                PrintStream pout = new PrintStream(out);

                try {
                    // Read first line of request
                    String request = in.readLine();
                    if (request == null)
                        continue;

                    // Ignore the rest
                    while (true) {
                        String ignore = in.readLine();
                        if (ignore == null || ignore.length() == 0)
                            break;
                    }

                    if (!request.startsWith("GET ") || !(request.endsWith(" HTTP/1.0") || request.endsWith(" HTTP/1.1"))) {
                        pout.print(
                            "HTTP/1.0 400 Bad Request" + NEW_LINE +
                            NEW_LINE
                        );
                    } else {
                        String path = request.substring(4, request.length()-9);
                        String[] params = path.contains("?") ? path.split("\\?")[1].split("\\&") : null;

                        if (path.startsWith("/get")) {
                            String id = null;
                            for (String param : params) {
                                if (param.startsWith("id=")) {
                                    id = URLDecoder.decode(param.substring(3), "UTF-8");
                                }

                                if (id != null) {
                                    break;
                                }
                            }
                            
                            String json = getter.get(id);
                            
                            pout.print(
                                "HTTP/1.0 200 OK" + NEW_LINE +
                                "Cache-Control: no-store" + NEW_LINE +
                                "Cache-Control: max-age=0" + NEW_LINE +
                                "Content-Type: application/json; charset=utf-8" + NEW_LINE +
                                "Content-length: " + (json != null ? json.length() : 0) + NEW_LINE +
                                NEW_LINE +
                                json
                            );
                        } else if (path.startsWith("/set")) {
                            String id = null;
                            String json = null;
                            for (String param : params) {
                                if (param.startsWith("id=")) {
                                    id = URLDecoder.decode(param.substring(3), "UTF-8");
                                } else if (param.startsWith("json=")) {
                                    json = URLDecoder.decode(param.substring(5), "UTF-8");
                                }

                                if (id != null && json != null) {
                                    break;
                                }
                            }

                            setter.set(id, json);

                            pout.print(
                                "HTTP/1.0 200 OK" + NEW_LINE +
                                "Content-length: 0" + NEW_LINE +
                                NEW_LINE
                            );
                        } else {
                            pout.print(
                                "HTTP/1.0 400 Bad Request" + NEW_LINE +
                                NEW_LINE
                            );
                        }
                    }
                } catch (Throwable t) {
                    System.err.println("Error handling request: " + t);
                    t.printStackTrace(System.err);

                    pout.print(
                        "HTTP/1.0 500 Internal Server Error" + NEW_LINE +
                        NEW_LINE
                    );
                }

                pout.close();
            }
        } catch (Throwable t) {
            System.err.println("Could not start server: " + t);
            t.printStackTrace(System.err);
        }

        if (socket != null) {
            try {
                socket.close();
            } catch (Throwable t) {
                System.err.println("Could not stop server: " + t);
                t.printStackTrace(System.err);
            }
        }
    }
}