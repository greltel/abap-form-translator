import { SQLiteDatabaseClient } from "@abaplint/database-sqlite";

// Wires an in-memory SQLite database into the transpiled runtime, so that
// CL_OSQL_TEST_ENVIRONMENT and the SELECT in GET_TRANSLATIONS behave the same
// way off-stack as they do in the ABAP system.
export async function setupDatabase(abap, schemas, insert) {
  const client = new SQLiteDatabaseClient();
  await client.connect();
  await client.execute(schemas.sqlite);
  await client.execute(insert);
  abap.context.databaseConnections["DEFAULT"] = client;
  abap.builtin.sy.get().dbsys.set("sqlite");
}
