import java.net.*;
import java.io.*;

import com.sun.net.httpserver.*;

public class Server {
    private HttpServer _server = null;

    public interface Getter {
        // Request path format: http://localhost:8080/get?id=abc123
        // Request body: null
        // Response body: JSON Object
        String get(String id);
    }

    public interface Setter {
        // Request path format: http://localhost:8080/set?id=abc123&json=%7B%22data%22:%22abcde12345%22%7D
        // Request body: null
        // Response body: null
        void set(String id, String json);
    }

    public Server(Getter getter, Setter setter) throws IOException {
        if (_server != null) {
            _server.stop(0);
        }
        
        _server = HttpServer.create(new InetSocketAddress(8080), 0);

        _server.createContext("/get", new HttpHandler() {
            public void handle(HttpExchange exchange) throws IOException {
                double totalStartTime = System.nanoTime();
                String query = exchange.getRequestURI().getQuery();
                String[] params = query != null ? query.split("\\&") : null;
                
                String id = null;
                for (String param : params) {
                    if (param.startsWith("id=")) {
                        id = URLDecoder.decode(param.substring(3), "UTF-8");
                        break;
                    }
                }
                
                double dbStartTime = System.nanoTime();
                String json = getter.get(id);
                double dbDuration = ((System.nanoTime() - dbStartTime) / (double)1000000); // Milliseconds
                double totalDuration = ((System.nanoTime() - totalStartTime) / (double)1000000); // Milliseconds

                _addResponseHeaders(exchange, totalDuration, dbDuration);

                if (json == null) {
                    json = "";
                }

                exchange.sendResponseHeaders(200, json.length());

                OutputStream out = exchange.getResponseBody();
                out.write(json.getBytes());

                exchange.close();
            }
        });

        _server.createContext("/set", new HttpHandler() {
            public void handle(HttpExchange exchange) throws IOException {
                double totalStartTime = System.nanoTime();
                String query = exchange.getRequestURI().getQuery();
                String[] params = query != null ? query.split("\\&") : null;

                String id = null;
                String json = null;
                for (String param : params) {
                    if (param.startsWith("id=")) {
                        id = URLDecoder.decode(param.substring(3), "UTF-8");
                        // break;
                    }

                    if (param.startsWith("json=")) {
                        json = URLDecoder.decode(param.substring(5), "UTF-8");
                    }

                    if (id != null && json != null) {
                        break;
                    }
                }

                // int contentLength = Integer.parseInt(exchange.getRequestHeaders().getFirst("Content-Length"));
                // byte[] body = new byte[contentLength];
                // exchange.getRequestBody().read(body);
                // String json = new String(body, Charset.forName(StandardCharsets.UTF_8.name()));

                double dbStartTime = System.nanoTime();
                setter.set(id, json);
                double dbDuration = ((System.nanoTime() - dbStartTime) / (double)1000000); // Milliseconds
                double totalDuration = ((System.nanoTime() - totalStartTime) / (double)1000000); // Milliseconds

                _addResponseHeaders(exchange, totalDuration, dbDuration);

                exchange.sendResponseHeaders(200, -1);
                exchange.close();
            }
        });

        _server.start();
    }

    private void _addResponseHeaders(HttpExchange exchange, double totalDuration, double dbDuration) {
        Headers responseHeaders = exchange.getResponseHeaders();

        responseHeaders.add("Cache-Control", "no-store, max-age=0");
        responseHeaders.add("Content-Type", "application/json; charset=utf-8");
        responseHeaders.add("Connection", "keep-alive");
        responseHeaders.add("Server-Timing", "total;dur=" + totalDuration + ", db;dur=" + dbDuration);
    }
}