// =============================================================================
// Optional VCD waveform dump - shared include for every DSD-8 testbench (tb/)
//
// Simulation output is UNCHANGED by default. A waveform (.vcd) file is only
// written when the simulator is invoked with a +VCD plusarg:
//
//     vvp sim/tb_alu.vvp +VCD=sim/waves/tb_alu.vcd     (explicit file)
//     vvp sim/tb_alu.vvp +VCD                           (default name)
//
// Recommended: use "make wave TB=tb_alu [TEST=T01]" or scripts/run_wave.py,
// which chains iverilog -> vvp (+VCD) -> GTKWave automatically.
//
// The .vcd files are stored in sim/waves/ and opened with:
//     tools/iverilog/app/gtkwave/bin/gtkwave.exe <file>.vcd
// =============================================================================

reg [511:0] wave_vcd_file;

initial begin : wave_dump
    if ($test$plusargs("VCD")) begin
        if (!$value$plusargs("VCD=%s", wave_vcd_file))
            wave_vcd_file = "sim/waves/wave.vcd";
        $dumpfile(wave_vcd_file);
        $dumpvars;
    end
end
