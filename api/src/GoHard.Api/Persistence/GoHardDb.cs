using Microsoft.EntityFrameworkCore;

namespace GoHard.Api.Persistence;

public class GoHardDb(DbContextOptions<GoHardDb> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Operation> Operations => Set<Operation>();
    public DbSet<TrainingContext> TrainingContexts => Set<TrainingContext>();
    public DbSet<Plan> Plans => Set<Plan>();
    public DbSet<Occasion> Occasions => Set<Occasion>();
    public DbSet<Workout> Workouts => Set<Workout>();
    public DbSet<WorkoutExercise> WorkoutExercises => Set<WorkoutExercise>();
    public DbSet<WorkoutSet> WorkoutSets => Set<WorkoutSet>();
    public DbSet<FoodEntry> FoodEntries => Set<FoodEntry>();
    public DbSet<SavedFood> SavedFoods => Set<SavedFood>();
    public DbSet<SavedMeal> SavedMeals => Set<SavedMeal>();
    public DbSet<WaterEntry> WaterEntries => Set<WaterEntry>();
    public DbSet<CustomExercise> CustomExercises => Set<CustomExercise>();
    public DbSet<CatalogExercise> CatalogExercises => Set<CatalogExercise>();
    public DbSet<Run> Runs => Set<Run>();
    public DbSet<RouteChunk> RouteChunks => Set<RouteChunk>();
    public DbSet<BodyMetric> BodyMetrics => Set<BodyMetric>();
    public DbSet<WeeklyGoal> WeeklyGoals => Set<WeeklyGoal>();
    public DbSet<ExerciseIncrement> ExerciseIncrements => Set<ExerciseIncrement>();
    public DbSet<Proposal> Proposals => Set<Proposal>();
    public DbSet<AuthChallenge> AuthChallenges => Set<AuthChallenge>();
    public DbSet<MailMessage> MailMessages => Set<MailMessage>();
    public DbSet<PreviewOverride> PreviewOverrides => Set<PreviewOverride>();
    public DbSet<AiUsage> AiUsage => Set<AiUsage>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.HasIndex(x => x.Email).IsUnique();
            e.Property(x => x.Email).HasMaxLength(320);
            e.Property(x => x.DisplayName).HasMaxLength(80);
            e.Property(x => x.Revision).IsConcurrencyToken();
        });
        Owned<RefreshToken>(b, x => x.UserId).HasIndex(x => x.TokenHash).IsUnique();
        Owned<Operation>(b, x => x.UserId).HasKey(x => new { x.UserId, x.OperationId });
        Owned<TrainingContext>(b, x => x.UserId).HasKey(x => x.UserId);
        b.Entity<TrainingContext>().Property(x => x.Revision).IsConcurrencyToken();

        Owned<Plan>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<Plan>().HasMany(x => x.Occasions).WithOne().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.Cascade);
        Owned<Occasion>(b, x => x.UserId);
        b.Entity<Plan>(e =>
        {
            e.Property(x => x.WorkoutsJson).HasColumnType("jsonb");
            e.Property(x => x.ScheduleJson).HasColumnType("jsonb");
            e.Property(x => x.TemplateId).HasMaxLength(64);
        });
        // One occurrence per sequence index: a retry, a second device or a lost response cannot create a second one.
        // The existing PlanId index stays declared so the migration that added the next one is purely additive.
        b.Entity<Occasion>().HasIndex(x => x.PlanId);
        b.Entity<Occasion>().HasIndex(x => new { x.PlanId, x.SequenceIndex }).IsUnique().HasFilter("\"SequenceIndex\" IS NOT NULL");

        // Plan/occasion links never cascade into performed history.
        Owned<Workout>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<Workout>().HasOne<Plan>().WithMany().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<Workout>().HasOne<Occasion>().WithMany().HasForeignKey(x => x.OccasionId).OnDelete(DeleteBehavior.SetNull);
        b.Entity<Workout>().HasMany(x => x.Exercises).WithOne().HasForeignKey(x => x.WorkoutId).OnDelete(DeleteBehavior.Cascade);
        Owned<WorkoutExercise>(b, x => x.UserId).HasMany(x => x.Sets).WithOne().HasForeignKey(x => x.ExerciseId).OnDelete(DeleteBehavior.Cascade);
        Owned<WorkoutSet>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<WorkoutSet>().Property(x => x.LoadKg).HasPrecision(9, 3);
        b.Entity<WorkoutExercise>().Property(x => x.TargetLoadKg).HasPrecision(9, 3);
        b.Entity<WorkoutSet>().HasIndex(x => x.WorkoutId);

        Owned<FoodEntry>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<FoodEntry>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.DayKey });
            e.Property(x => x.Calories).HasPrecision(9, 2);
            e.Property(x => x.ProteinG).HasPrecision(9, 2);
            e.Property(x => x.CarbsG).HasPrecision(9, 2);
            e.Property(x => x.FatG).HasPrecision(9, 2);
            e.Property(x => x.SourceJson).HasColumnType("jsonb");
        });
        Owned<WaterEntry>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<WaterEntry>(e =>
        {
            e.HasIndex(x => new { x.UserId, x.DayKey });
            e.Property(x => x.VolumeMl).HasPrecision(9, 3);
        });
        Owned<SavedFood>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<SavedFood>().Property(x => x.ItemJson).HasColumnType("jsonb");
        Owned<SavedMeal>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<SavedMeal>().Property(x => x.BodyJson).HasColumnType("jsonb");
        b.Entity<CatalogExercise>().HasKey(x => x.Key);
        Owned<CustomExercise>(b, x => x.UserId).Property(x => x.Revision).IsConcurrencyToken();
        b.Entity<CustomExercise>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(80);
            e.Property(x => x.Category).HasMaxLength(40);
            e.Property(x => x.Equipment).HasMaxLength(40);
        });

        Owned<Run>(b, x => x.UserId).Property(x => x.DistanceMeters).HasPrecision(10, 1);
        b.Entity<Run>(e =>
        {
            e.Property(x => x.ActivityType).HasMaxLength(8).HasDefaultValue("run");
            e.Property(x => x.Title).HasMaxLength(80);
            e.Property(x => x.Notes).HasMaxLength(1000);
            e.Property(x => x.MetricsJson).HasColumnType("jsonb");
            e.Property(x => x.RouteState).HasMaxLength(12).HasDefaultValue("none");
        });
        Owned<RouteChunk>(b, x => x.UserId).HasKey(x => new { x.RunId, x.Index });
        b.Entity<RouteChunk>().HasOne<Run>().WithMany().HasForeignKey(x => x.RunId).OnDelete(DeleteBehavior.Cascade);
        // Four decimals keep a quarter inch (0.635 cm) and a pound entry exact through a kg/lb round trip.
        Owned<BodyMetric>(b, x => x.UserId).Property(x => x.WeightKg).HasPrecision(9, 4);
        b.Entity<BodyMetric>(e =>
        {
            e.Property(x => x.BodyFatPercent).HasPrecision(5, 2);
            foreach (var cm in new[] { nameof(BodyMetric.WaistCm), nameof(BodyMetric.ChestCm), nameof(BodyMetric.LeftUpperArmCm),
                         nameof(BodyMetric.RightUpperArmCm), nameof(BodyMetric.LeftThighCm), nameof(BodyMetric.RightThighCm) })
                e.Property(cm).HasPrecision(8, 4);
        });
        // One effective record per owner and week: a retry or a second phone cannot create a competing one.
        Owned<WeeklyGoal>(b, x => x.UserId).HasKey(x => new { x.UserId, x.WeekStart });
        b.Entity<WeeklyGoal>().Property(x => x.Revision).IsConcurrencyToken();
        // One increment per owner and exercise identity.
        Owned<ExerciseIncrement>(b, x => x.UserId).HasKey(x => new { x.UserId, x.ExerciseKey });
        b.Entity<ExerciseIncrement>(e =>
        {
            e.Property(x => x.ExerciseKey).HasMaxLength(80);
            e.Property(x => x.IncrementKg).HasPrecision(9, 5);
            e.Property(x => x.Revision).IsConcurrencyToken();
        });
        Owned<Proposal>(b, x => x.UserId).HasOne<Plan>().WithMany().HasForeignKey(x => x.PlanId).OnDelete(DeleteBehavior.Cascade);

        // Account email (docs/AUTHENTICATION_EMAIL.md). Both go with the account; unknown-address challenges have no owner.
        Owned<AuthChallenge>(b, x => x.UserId).HasIndex(x => new { x.EmailKey, x.Purpose, x.CreatedAtUtc });
        b.Entity<AuthChallenge>(e =>
        {
            e.Property(x => x.Purpose).HasMaxLength(32);
            e.Property(x => x.EmailKey).HasMaxLength(64);
            e.HasIndex(x => x.GrantHash).IsUnique();
        });
        Owned<MailMessage>(b, x => x.UserId).HasIndex(x => new { x.State, x.NextAttemptAtUtc });
        b.Entity<MailMessage>(e =>
        {
            e.Property(x => x.Kind).HasMaxLength(32);
            e.Property(x => x.Language).HasMaxLength(8);
            e.Property(x => x.State).HasMaxLength(16);
            e.HasOne<AuthChallenge>().WithMany().HasForeignKey(x => x.ChallengeId).OnDelete(DeleteBehavior.Cascade);
        });

        // GoHard Plus preview (docs/PLUS_PREVIEW.md). One charge per request, whatever retries or instances do.
        Owned<PreviewOverride>(b, x => x.UserId).HasKey(x => x.UserId);
        b.Entity<PreviewOverride>().Property(x => x.Tier).HasMaxLength(8);
        Owned<AiUsage>(b, x => x.UserId).HasIndex(x => new { x.UserId, x.AtUtc });
        b.Entity<AiUsage>(e =>
        {
            e.Property(x => x.Scope).HasMaxLength(16);
            e.HasIndex(x => new { x.UserId, x.Scope, x.RequestId }).IsUnique().HasFilter("\"Counted\"");
        });
    }

    /// <summary>Every owned row is indexed by owner and erased with the account.</summary>
    private static Microsoft.EntityFrameworkCore.Metadata.Builders.EntityTypeBuilder<T> Owned<T>(
        ModelBuilder b, System.Linq.Expressions.Expression<Func<T, object?>> userId) where T : class
    {
        var e = b.Entity<T>();
        e.HasOne<User>().WithMany().HasForeignKey(userId).OnDelete(DeleteBehavior.Cascade);
        return e;
    }
}

/// <summary>Lets `dotnet ef migrations add` build the model without local secrets. It never connects.</summary>
public sealed class DesignTimeFactory : Microsoft.EntityFrameworkCore.Design.IDesignTimeDbContextFactory<GoHardDb>
{
    public GoHardDb CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<GoHardDb>().UseNpgsql("Host=design-time-only").Options);
}
