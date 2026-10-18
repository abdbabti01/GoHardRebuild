using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddExerciseMedia : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "MediaCatalogStates",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    Revision = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MediaCatalogStates", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "MediaDrafts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CatalogKey = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Variant = table.Column<string>(type: "text", nullable: false),
                    Title = table.Column<string>(type: "text", nullable: false),
                    Creator = table.Column<string>(type: "text", nullable: false),
                    RightsKind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    LicenceName = table.Column<string>(type: "text", nullable: true),
                    LicenceUrl = table.Column<string>(type: "text", nullable: true),
                    SourceUrl = table.Column<string>(type: "text", nullable: true),
                    RightsNotice = table.Column<string>(type: "text", nullable: false),
                    RightsConfirmed = table.Column<bool>(type: "boolean", nullable: false),
                    ContentType = table.Column<string>(type: "text", nullable: false),
                    DeclaredBytes = table.Column<long>(type: "bigint", nullable: false),
                    OriginalKey = table.Column<string>(type: "text", nullable: false),
                    OriginalBytes = table.Column<long>(type: "bigint", nullable: true),
                    UploadExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ProcessedKey = table.Column<string>(type: "text", nullable: true),
                    PosterKey = table.Column<string>(type: "text", nullable: true),
                    Bytes = table.Column<long>(type: "bigint", nullable: true),
                    Sha256 = table.Column<string>(type: "text", nullable: true),
                    DurationSeconds = table.Column<double>(type: "double precision", nullable: true),
                    Width = table.Column<int>(type: "integer", nullable: true),
                    Height = table.Column<int>(type: "integer", nullable: true),
                    Error = table.Column<string>(type: "text", nullable: true),
                    Attempts = table.Column<int>(type: "integer", nullable: false),
                    LeaseUntilUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    LeaseOwner = table.Column<Guid>(type: "uuid", nullable: true),
                    PublishedVersionId = table.Column<Guid>(type: "uuid", nullable: true),
                    OriginalDeleted = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uuid", nullable: false),
                    Revision = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PublishedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MediaDrafts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "MediaVersions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CatalogKey = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    DraftId = table.Column<Guid>(type: "uuid", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    ClipKey = table.Column<string>(type: "text", nullable: false),
                    PosterKey = table.Column<string>(type: "text", nullable: false),
                    Bytes = table.Column<long>(type: "bigint", nullable: false),
                    Sha256 = table.Column<string>(type: "text", nullable: false),
                    DurationSeconds = table.Column<double>(type: "double precision", nullable: false),
                    Width = table.Column<int>(type: "integer", nullable: false),
                    Height = table.Column<int>(type: "integer", nullable: false),
                    Variant = table.Column<string>(type: "text", nullable: false),
                    Title = table.Column<string>(type: "text", nullable: false),
                    Creator = table.Column<string>(type: "text", nullable: false),
                    RightsKind = table.Column<string>(type: "text", nullable: false),
                    LicenceName = table.Column<string>(type: "text", nullable: true),
                    LicenceUrl = table.Column<string>(type: "text", nullable: true),
                    SourceUrl = table.Column<string>(type: "text", nullable: true),
                    RightsNotice = table.Column<string>(type: "text", nullable: false),
                    PublishedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    WithdrawnAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MediaVersions", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "MediaCatalogStates",
                columns: new[] { "Id", "Revision", "UpdatedAtUtc" },
                values: new object[] { 1, 0, new DateTime(2026, 10, 18, 0, 0, 0, 0, DateTimeKind.Utc) });

            migrationBuilder.CreateIndex(
                name: "IX_MediaDrafts_CatalogKey",
                table: "MediaDrafts",
                column: "CatalogKey");

            migrationBuilder.CreateIndex(
                name: "IX_MediaDrafts_Status",
                table: "MediaDrafts",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_MediaVersions_ActiveKey",
                table: "MediaVersions",
                column: "CatalogKey",
                unique: true,
                filter: "\"IsActive\"");

            migrationBuilder.CreateIndex(
                name: "IX_MediaVersions_DraftId",
                table: "MediaVersions",
                column: "DraftId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MediaCatalogStates");

            migrationBuilder.DropTable(
                name: "MediaDrafts");

            migrationBuilder.DropTable(
                name: "MediaVersions");
        }
    }
}
