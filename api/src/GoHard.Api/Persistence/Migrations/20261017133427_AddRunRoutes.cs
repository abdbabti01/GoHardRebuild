using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRunRoutes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ActivityType",
                table: "Runs",
                type: "character varying(8)",
                maxLength: 8,
                nullable: false,
                defaultValue: "run");

            migrationBuilder.AddColumn<string>(
                name: "MetricsJson",
                table: "Runs",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "Runs",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RouteChunkCount",
                table: "Runs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "RouteState",
                table: "Runs",
                type: "character varying(12)",
                maxLength: 12,
                nullable: false,
                defaultValue: "none");

            migrationBuilder.AddColumn<string>(
                name: "Title",
                table: "Runs",
                type: "character varying(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "RouteChunks",
                columns: table => new
                {
                    RunId = table.Column<Guid>(type: "uuid", nullable: false),
                    Index = table.Column<int>(type: "integer", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    FirstSeq = table.Column<int>(type: "integer", nullable: false),
                    LastSeq = table.Column<int>(type: "integer", nullable: false),
                    EntryCount = table.Column<int>(type: "integer", nullable: false),
                    EntriesJson = table.Column<string>(type: "text", nullable: false),
                    Sha256 = table.Column<string>(type: "text", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RouteChunks", x => new { x.RunId, x.Index });
                    table.ForeignKey(
                        name: "FK_RouteChunks_Runs_RunId",
                        column: x => x.RunId,
                        principalTable: "Runs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RouteChunks_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RouteChunks_UserId",
                table: "RouteChunks",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RouteChunks");

            migrationBuilder.DropColumn(
                name: "ActivityType",
                table: "Runs");

            migrationBuilder.DropColumn(
                name: "MetricsJson",
                table: "Runs");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "Runs");

            migrationBuilder.DropColumn(
                name: "RouteChunkCount",
                table: "Runs");

            migrationBuilder.DropColumn(
                name: "RouteState",
                table: "Runs");

            migrationBuilder.DropColumn(
                name: "Title",
                table: "Runs");
        }
    }
}
