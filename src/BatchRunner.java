import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

import org.nlogo.headless.HeadlessWorkspace;

public class BatchRunner {
  public static void main(String[] args) throws Exception {
    if (args.length != 6) {
      throw new IllegalArgumentException(
          "Usage: BatchRunner <model> <output> <runs> <mexican_concentration> <cos_fatigue> <time_limit_steps>");
    }

    String modelPath = args[0];
    Path outputPath = Path.of(args[1]);
    int runs = Integer.parseInt(args[2]);
    int mexicanConcentration = Integer.parseInt(args[3]);
    int cosFatigue = Integer.parseInt(args[4]);
    int timeLimitSteps = Integer.parseInt(args[5]);

    Path outputParent = outputPath.toAbsolutePath().getParent();
    if (outputParent != null) {
      Files.createDirectories(outputParent);
    }
    long startedAt = System.currentTimeMillis();
    System.out.printf(
        Locale.US,
        "Starting batch run: runs=%d concentration=%d fatigue=%d limit=%d model=%s%n",
        runs,
        mexicanConcentration,
        cosFatigue,
        timeLimitSteps,
        modelPath);

    HeadlessWorkspace workspace = HeadlessWorkspace.newInstance();
    try (PrintWriter writer = new PrintWriter(Files.newBufferedWriter(outputPath))) {
      workspace.open(modelPath);
      writer.println(
          "run,mexican_concentration,cos_fatigue,texian_casualties,mexican_casualties,mexican_captured,cos_remaining,battle_duration,texian_side_morale,mexican_side_morale,texian_win");

      for (int run = 1; run <= runs; run++) {
        long runStartedAt = System.currentTimeMillis();
        System.out.printf(Locale.US, "Run %d/%d: setup%n", run, runs);
        workspace.command("random-seed new-seed");
        workspace.command("set mexican-concentration " + mexicanConcentration);
        workspace.command("set cos-fatigue " + cosFatigue);
        workspace.command("setup");

        int steps = 0;
        while (!asBoolean(workspace.report("battle-over?")) && steps < timeLimitSteps) {
          workspace.command("go");
          steps++;
          if (steps % 100 == 0) {
            System.out.printf(Locale.US, "Run %d/%d: %d steps%n", run, runs, steps);
          }
        }

        writer.printf(
            Locale.US,
            "%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s%n",
            run,
            mexicanConcentration,
            cosFatigue,
            csvValue(workspace.report("texian-casualties")),
            csvValue(workspace.report("mexican-casualties")),
            csvValue(workspace.report("mexican-captured")),
            csvValue(workspace.report("count mexicans with [is-cos-troop?]")),
            csvValue(workspace.report("battle-duration")),
            csvValue(workspace.report("texian-side-morale")),
            csvValue(workspace.report("mexican-side-morale")),
            csvValue(workspace.report("texian-win?")));
        writer.flush();

        long runElapsedMs = System.currentTimeMillis() - runStartedAt;
        System.out.printf(Locale.US, "Run %d/%d: complete in %dms (%d steps)%n", run, runs, runElapsedMs, steps);
      }
      long totalElapsedMs = System.currentTimeMillis() - startedAt;
      System.out.printf(Locale.US, "Batch complete in %dms. Results written to %s%n", totalElapsedMs, outputPath);
    } finally {
      workspace.dispose();
    }
  }

  private static boolean asBoolean(Object value) {
    return value instanceof Boolean && (Boolean) value;
  }

  private static String csvValue(Object value) {
    String text = String.valueOf(value);
    if (text.contains(",") || text.contains("\"") || text.contains("\n")) {
      return "\"" + text.replace("\"", "\"\"") + "\"";
    }
    return text;
  }
}
