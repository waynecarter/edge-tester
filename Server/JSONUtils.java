import java.util.*;

import org.json.*;

public class JSONUtils {
    public static String json(Map<String, Object> map) {
        if (map != null) {
            return new JSONObject(map).toString();
        }

        return null;
    }

    public static Map<String, Object> map(String json) {
        try {
            return map(new JSONObject(json));
        } catch (JSONException e) {
            throw new IllegalArgumentException(e);
        }
    }

    private static Map<String, Object> map(JSONObject json) throws JSONException {
        Map<String, Object> map = new HashMap<String, Object>();
        Iterator<String> keys = json.keys();
        
        while(keys.hasNext()) {
            String key = keys.next();
            Object value = json.get(key);
            
            if (value instanceof JSONArray) {
                value = list((JSONArray) value);
            } else if (value instanceof JSONObject) {
                value = map((JSONObject) value);
            }

            map.put(key, value);

        }

        return map;
    }

    private static List<Object> list(JSONArray array) throws JSONException {
        List<Object> list = new ArrayList<Object>();

        for(int i = 0; i < array.length(); i++) {
            Object value = array.get(i);
            
            if (value instanceof JSONArray) {
                value = list((JSONArray) value);
            } else if (value instanceof JSONObject) {
                value = map((JSONObject) value);
            }

            list.add(value);

        }   return list;
    }
}
