import { SQLiteDatabaseClient } from "@abaplint/database-sqlite";

export async function setupDatabase(abap, schemas, insert) {
  const client = new SQLiteDatabaseClient();
  await client.connect();
  await client.execute(schemas.sqlite);
  await client.execute(insert);
  abap.context.databaseConnections["DEFAULT"] = client;
}
