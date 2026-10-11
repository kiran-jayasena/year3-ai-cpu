from pathlib import Path
import shutil

root = Path(__file__).resolve().parent
gen = root / "project" / "mb_reference.gen" / "sources_1" / "bd" / "mb_system"
out = root / "sim_sources"
out.mkdir(exist_ok=True)
for name in ["mb_system_ilmb_bram_0", "mb_system_dlmb_bram_0", "mb_system_interrupt_const_0"]:
    src = gen / "ip" / name / "sim" / f"{name}.v"
    dst = out / f"{name}.v"
    text = src.read_text(encoding="utf-8")
    if "ilmb" in name:
        text = text.replace('.C_LOAD_INIT_FILE(0)', '.C_LOAD_INIT_FILE(1)').replace('.C_INIT_FILE_NAME("no_coe_file_loaded")', '.C_INIT_FILE_NAME("imem.mif")').replace('.C_INIT_FILE("mb_system_ilmb_bram_0.mem")', '.C_INIT_FILE("imem.mif")')
    if "dlmb" in name:
        text = text.replace('.C_LOAD_INIT_FILE(0)', '.C_LOAD_INIT_FILE(1)').replace('.C_INIT_FILE_NAME("no_coe_file_loaded")', '.C_INIT_FILE_NAME("dmem.mif")').replace('.C_INIT_FILE("mb_system_dlmb_bram_0.mem")', '.C_INIT_FILE("dmem.mif")')
    dst.write_text(text, encoding="utf-8")
shutil.copyfile(gen / "sim" / "mb_system.v", out / "mb_system.v")
