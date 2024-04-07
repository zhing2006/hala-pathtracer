use std::fs;
use serde::Deserialize;

// Shader project.
#[derive(Debug, Deserialize, Default, Clone)]
struct ShaderProject {
  pub name: String,
  pub global_macros: Vec<String>,
  pub optional_macro_combinations: Vec<Vec<String>>,
}

// Shader make file.
#[derive(Debug, Deserialize, Default, Clone)]
struct ShaderMakeFile {
  pub projects: Vec<ShaderProject>,
}

fn main() {
  println!("cargo:rerun-if-changed=src");

  let profile = std::env::var("PROFILE").unwrap();
  let output_dir = if profile == "debug" { "output/debug" } else { "output/release" };
  if !std::path::Path::new("src/make_shaders.yaml").exists() {
    panic!("The make_shaders.yaml file is not found.");
  }

  let make_str = std::fs::read_to_string("src/make_shaders.yaml").expect("Failed to read src/make_shaders.yaml file.");
  let make_file: ShaderMakeFile = serde_yaml::from_str(&make_str).expect("Failed to parse src/make_shaders.yaml file.");

  for project in make_file.projects.iter() {
    if !project.optional_macro_combinations.is_empty() {
      for optional_macros in project.optional_macro_combinations.iter() {
        compile_shaders(&project.name, output_dir, &project.global_macros, optional_macros);
      }
    } else {
      compile_shaders(&project.name, output_dir, &project.global_macros, &Vec::new());
    }
  }
}

/// Compile shaders in the specified directory.
/// param shader_dir: The directory of the shaders.
/// param output_dir: The output directory of the compiled shaders.
/// param global_macros: The global macros.
/// param optional_macros: The optional macros.
fn compile_shaders(shader_dir: &str, output_dir: &str, global_macros: &Vec<String>, optional_macros: &Vec<String>) {
  let profile = std::env::var("PROFILE").unwrap();
  let output_dir = format!("{}/{}/{}", output_dir, shader_dir, optional_macros.join("#"));
  // println!("cargo:warning=Output directory: {}", output_dir);

  let compiler = shaderc::Compiler::new()
    .ok_or("Failed to initialize the shader compiler.").unwrap();
  let mut options = shaderc::CompileOptions::new()
    .ok_or("Failed to initialize the shader compiler options.").unwrap();
  if profile == "debug" {
    options.set_optimization_level(shaderc::OptimizationLevel::Zero);
    options.set_generate_debug_info();
  } else {
    options.set_optimization_level(shaderc::OptimizationLevel::Performance);
  }
  options.set_target_env(shaderc::TargetEnv::Vulkan, (1 << 22) | (3 << 12) as u32);
  options.set_target_spirv(shaderc::SpirvVersion::V1_6);
  options.set_include_callback(|filename, _type, source, _include_depth| {
    let source_path = std::path::Path::new(source);
    let source_dir = source_path.parent().ok_or("Failed to get source directory.").unwrap();
    // println!("cargo:warning=Source dir: {:?}, File name: {}", source_dir, filename);
    let path = if source_dir.starts_with("src") {
      format!("{}/{}", source_dir.to_str().ok_or("Failed to get source directory.").unwrap(), filename)
    } else {
      format!("src/{}/{}", source_dir.to_str().ok_or("Failed to get source directory.").unwrap(), filename)
    };
    // println!("cargo:warning=Include file: {}, Include source: {}, Path: {}", filename, source, path);
    let path = if !std::path::Path::new(&path).exists() {
      format!("src/{}", filename)
    } else {
      path
    };
    // println!("cargo:warning=Include file: {}, Include source: {}, Path: {}", filename, source, path);
    let source = match fs::read_to_string(&path) {
      Ok(source) => source,
      Err(_) => return Err(format!("Failed to read file: {}", path)),
    };
    Ok(shaderc::ResolvedInclude {
      resolved_name: filename.to_string(),
      content: source,
    })
  });

  for macro_name in global_macros.iter() {
    options.add_macro_definition(macro_name, Some("1"));
  }
  for macro_name in optional_macros.iter() {
    options.add_macro_definition(&format!("USE_{}", macro_name), Some("1"));
  }

  // Make output directory if it doesn't exist.
  fs::create_dir_all(&output_dir).unwrap();

  // Find all *.glsl files in src directory.
  let mut glsl_files = Vec::new();
  for entry in fs::read_dir(format!("src/{}", shader_dir)).unwrap() {
    let entry = entry.unwrap();
    let path = entry.path();
    if path.is_file() && path.extension().unwrap() == "glsl" {
      glsl_files.push(path.clone());
    }
    if path.is_dir() {
      for entry in fs::read_dir(path).unwrap() {
        let entry = entry.unwrap();
        let path = entry.path();
        if path.is_file() && path.extension().unwrap() == "glsl" {
          glsl_files.push(path.clone());
        }
      }
    }
  }

  // Compile all *.glsl files into *.spv files.
  for glsl_file in glsl_files {
    // Get filename without extension.
    let glsl_file_stem = glsl_file.file_stem().unwrap().to_str().unwrap();
    // Get relative path of the glsl file without filename.
    let glsl_file_path = glsl_file.parent().unwrap().strip_prefix(format!("src/{}", shader_dir)).unwrap();
    // Get string after the last dot in file_stem.
    let shader_kind = glsl_file_stem.split('.').last().unwrap();

    // Match shader kind from filename.
    let shader_kind = match shader_kind {
      "comp" => shaderc::ShaderKind::Compute,
      "frag" => shaderc::ShaderKind::Fragment,
      "vert" => shaderc::ShaderKind::Vertex,
      "rgen" => shaderc::ShaderKind::RayGeneration,
      "rahit" => shaderc::ShaderKind::AnyHit,
      "rchit" => shaderc::ShaderKind::ClosestHit,
      "rmiss" => shaderc::ShaderKind::Miss,
      "rint" => shaderc::ShaderKind::Intersection,
      "rcall" => shaderc::ShaderKind::Callable,
      _ => shaderc::ShaderKind::InferFromSource,
    };

    if shader_kind == shaderc::ShaderKind::InferFromSource {
      // We don't know the shader kind, so we skip this file.
      continue;
    }

    // Compile the glsl file into a binary result.
    let binary_result = compiler.compile_into_spirv(
      &fs::read_to_string(&glsl_file).unwrap(),
      shader_kind,
      glsl_file.to_str().unwrap(),
      "main",
      Some(&options)
    ).unwrap();

    let output_dir = format!("{}/{}", &output_dir, glsl_file_path.to_str().unwrap());
    // Make output directory if it doesn't exist.
    fs::create_dir_all(&output_dir).unwrap();

    // Save the binary result to a file.
    let mut file = fs::File::create(format!("{}/{}.spv", output_dir, glsl_file_stem)).unwrap();
    std::io::Write::write_all(&mut file, binary_result.as_binary_u8()).unwrap();
  }
}