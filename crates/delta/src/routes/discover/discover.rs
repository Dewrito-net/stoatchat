use revolt_database::{Database, Server};
use revolt_models::v0;
use revolt_result::{create_error, Result};

use futures::TryStreamExt;
use mongodb::bson::doc;

use rocket::serde::json::Json;
use rocket::State;

/// # Discover
///
/// Return all discoverable servers in the same format as the official Stoat API.
#[openapi(tag = "Discover")]
#[get("/")]
pub async fn discover(
    db: &State<Database>,
) -> Result<Json<Vec<v0::Server>>> {
    let mut cursor = db
        .servers
        .find(doc! { "discoverable": true }, None)
        .await
        .map_err(|_| create_error!(DatabaseError))?;

    let mut out = Vec::new();

    while let Some(server) = cursor
        .try_next()
        .await
        .map_err(|_| create_error!(DatabaseError))?
    {
        out.push(server.into());
    }

    Ok(Json(out))
}
