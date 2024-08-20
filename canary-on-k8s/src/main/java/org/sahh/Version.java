package org.sahh;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/")
public class Version {
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public String version() {
        return "{\"version\": \"2.0.0\"}";
    }
}
