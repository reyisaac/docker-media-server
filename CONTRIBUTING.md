# Contributing to Media Automation Stack

Thank you for your interest in contributing! This project aims to make self-hosted media automation accessible to everyone.

## 🤝 How to Contribute

### Reporting Issues

**Before creating an issue**, please:
1. Check if the issue already exists
2. Review the [Troubleshooting Guide](docs/SETUP_INSTRUCTIONS.md#troubleshooting)
3. Make sure you're using the latest version

**When reporting bugs**, include:
- Your OS version (e.g., Pop!_OS 22.04, Ubuntu 24.04)
- Docker version: `docker --version`
- GPU info (if relevant): `nvidia-smi`
- Steps to reproduce
- Error messages (full logs preferred)
- What you expected to happen

### Suggesting Enhancements

We welcome feature requests! Please:
- Check if someone already suggested it
- Explain the use case clearly
- Consider if it fits the project's scope (automated media management)

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes**:
   - Follow existing code style
   - Add comments for complex logic
   - Test on a fresh install if possible
3. **Update documentation**:
   - Update `README.md` if you changed setup steps
   - Update `docs/SETUP_INSTRUCTIONS.md` for new features
   - Add inline comments to scripts
4. **Commit with clear messages**:
   ```
   Add feature: Automatic Bazarr language configuration
   
   - Creates language profiles automatically
   - Detects system language preferences
   - Falls back to English if not detected
   ```
5. **Submit your PR** with:
   - What you changed
   - Why you changed it
   - How to test it

## 🎯 Project Goals

This project prioritizes:
- **Simplicity**: One command setup preferred
- **Security**: No credentials in code, VPN isolation
- **Documentation**: Clear guides for beginners
- **Automation**: Minimal manual configuration
- **Performance**: GPU transcoding, efficient workflows

## 📝 Development Setup

### Testing Changes

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/docker-media-server.git
cd docker-media-server

# Create test branch
git checkout -b feature/my-improvement

# Make changes, then test
./setup.sh --skip-deps  # Skip Docker/NVIDIA install

# Test specific services
docker compose up -d SERVICE_NAME
docker compose logs -f SERVICE_NAME
```

### Code Style

**Shell Scripts**:
- Use `#!/bin/bash` shebang
- Add header comment explaining purpose
- Use meaningful variable names
- Quote variables: `"$VAR"` not `$VAR`
- Check syntax: `shellcheck script.sh`

**Docker Compose**:
- Group related services
- Add comments for complex configs
- Use environment variables for customization
- Follow existing indentation (2 spaces)

**Documentation**:
- Use clear, simple language
- Provide examples
- Link to related docs
- Test commands before documenting

## 🔒 Security

**Never commit**:
- Credentials (API keys, passwords, tokens)
- `.env` files (use `env.example` template)
- VPN configs (`.ovpn` files)
- Personal paths or information

**Always**:
- Use `${ENV_VARS}` in `docker-compose.yml`
- Update `.gitignore` for sensitive files
- Document security implications
- Use HTTPS links in documentation

## 🧪 Testing

Before submitting:
- [ ] Fresh install works: `./setup.sh`
- [ ] Services start: `docker compose up -d`
- [ ] No errors in logs: `docker compose logs`
- [ ] Documentation is accurate
- [ ] No credentials exposed
- [ ] `.gitignore` protects sensitive files

## 💬 Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue
- **Security**: Email maintainer privately (see README)

## 📜 Code of Conduct

**Be respectful and constructive**:
- Welcome beginners and all skill levels
- Provide constructive feedback
- Focus on the issue, not the person
- Assume good intentions

**Not acceptable**:
- Harassment or discriminatory language
- Trolling or insulting comments
- Political or off-topic arguments
- Spam or self-promotion

Violations may result in comment deletion or bans.

## 🎉 Recognition

Contributors are recognized in:
- Git commit history
- Release notes (for significant features)
- This project's success! 🙌

Thank you for making this project better!

---

**Questions?** Open a Discussion on GitHub or check the [README](README.md).

