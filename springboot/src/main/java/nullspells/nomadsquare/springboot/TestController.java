package nullspells.nomadsquare.springboot;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestController {
    @GetMapping("/hello")
    public Map<String,String> hello() {
        return Map.of("msg","hello from spring");
    }
}
