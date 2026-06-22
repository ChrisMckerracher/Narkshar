using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Reflection;

namespace NarksharLauncher;

internal sealed class LauncherForm : Form
{
    private static readonly Image? HeroImage = LoadHeroImage();

    private readonly ProgressBar _progressBar = new();
    private readonly Label _statusLabel = new();
    private readonly Button _playButton = new();
    private readonly NarksharUpdater _updater;

    public LauncherForm()
    {
        _updater = new NarksharUpdater(AppContext.BaseDirectory);

        Text = "Narkshar";
        ClientSize = new Size(1120, 630);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(8, 9, 11);
        DoubleBuffered = true;

        _statusLabel.AutoSize = false;
        _statusLabel.BackColor = Color.FromArgb(26, 4, 10, 15);
        _statusLabel.ForeColor = Color.FromArgb(231, 241, 255);
        _statusLabel.Font = new Font("Segoe UI", 10.5f, FontStyle.Regular);
        _statusLabel.Text = "Checking Narkshar assets...";
        _statusLabel.TextAlign = ContentAlignment.MiddleLeft;
        _statusLabel.SetBounds(70, 536, 650, 34);

        _progressBar.Style = ProgressBarStyle.Continuous;
        _progressBar.Minimum = 0;
        _progressBar.Maximum = 100;
        _progressBar.Value = 0;
        _progressBar.SetBounds(72, 580, 520, 16);

        _playButton.Text = "PLAY";
        _playButton.Enabled = false;
        _playButton.Font = new Font("Segoe UI", 18.5f, FontStyle.Bold);
        _playButton.ForeColor = Color.FromArgb(241, 247, 255);
        _playButton.BackColor = Color.FromArgb(27, 118, 194);
        _playButton.FlatStyle = FlatStyle.Flat;
        _playButton.FlatAppearance.BorderColor = Color.FromArgb(155, 215, 255);
        _playButton.FlatAppearance.BorderSize = 1;
        _playButton.FlatAppearance.MouseOverBackColor = Color.FromArgb(38, 147, 232);
        _playButton.FlatAppearance.MouseDownBackColor = Color.FromArgb(15, 82, 145);
        _playButton.SetBounds(842, 534, 210, 72);
        _playButton.Click += PlayButton_Click;

        Controls.Add(_statusLabel);
        Controls.Add(_progressBar);
        Controls.Add(_playButton);

        Shown += LauncherForm_Shown;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        PaintHero(g);

        using var topShade = new LinearGradientBrush(ClientRectangle, Color.FromArgb(205, 0, 9, 18), Color.FromArgb(35, 0, 7, 14), 90f);
        g.FillRectangle(topShade, 0, 0, ClientSize.Width, 240);

        using var bottomShade = new LinearGradientBrush(ClientRectangle, Color.FromArgb(5, 0, 0, 0), Color.FromArgb(235, 0, 4, 8), 90f);
        g.FillRectangle(bottomShade, 0, 330, ClientSize.Width, ClientSize.Height - 330);

        using var sideShade = new LinearGradientBrush(ClientRectangle, Color.FromArgb(175, 0, 7, 12), Color.FromArgb(5, 0, 7, 12), 0f);
        g.FillRectangle(sideShade, 0, 0, 390, ClientSize.Height);

        using var framePen = new Pen(Color.FromArgb(145, 126, 208, 255), 2);
        g.DrawRectangle(framePen, 18, 18, ClientSize.Width - 36, ClientSize.Height - 36);
        using var innerFramePen = new Pen(Color.FromArgb(75, 7, 23, 40), 1);
        g.DrawRectangle(innerFramePen, 24, 24, ClientSize.Width - 48, ClientSize.Height - 48);

        using var titleFont = new Font("Georgia", 64f, FontStyle.Bold);
        DrawTextShadow(g, "Narkshar", titleFont, new PointF(61, 365), Color.FromArgb(240, 239, 248, 255), Color.FromArgb(210, 4, 10, 22), 4);

        using var subtitleFont = new Font("Segoe UI Semibold", 13f, FontStyle.Bold);
        DrawTextShadow(g, "Wrath 3.3.5a", subtitleFont, new PointF(72, 464), Color.FromArgb(225, 183, 222, 255), Color.FromArgb(190, 1, 8, 18), 2);

        var bandRect = new Rectangle(40, 516, ClientSize.Width - 80, 104);
        using var bandBrush = new SolidBrush(Color.FromArgb(225, 2, 12, 22));
        g.FillRectangle(bandBrush, bandRect);
        using var bandTop = new Pen(Color.FromArgb(115, 145, 218, 255), 1);
        g.DrawLine(bandTop, bandRect.Left, bandRect.Top, bandRect.Right, bandRect.Top);
        using var bandPen = new Pen(Color.FromArgb(120, 16, 43, 72), 1);
        g.DrawRectangle(bandPen, bandRect);

        using var buttonGlow = new LinearGradientBrush(_playButton.Bounds, Color.FromArgb(75, 87, 196, 255), Color.FromArgb(5, 87, 196, 255), 90f);
        g.FillRectangle(buttonGlow, new Rectangle(_playButton.Left - 8, _playButton.Top - 8, _playButton.Width + 16, _playButton.Height + 16));
    }

    private static Image? LoadHeroImage()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames().FirstOrDefault(name => name.EndsWith("narkshar-hero.png", StringComparison.Ordinal));
        if (resourceName is null)
        {
            return null;
        }

        using var stream = assembly.GetManifestResourceStream(resourceName);
        return stream is null ? null : Image.FromStream(stream);
    }

    private void PaintHero(Graphics g)
    {
        if (HeroImage is null)
        {
            using var fallback = new LinearGradientBrush(ClientRectangle, Color.FromArgb(0, 24, 39), Color.FromArgb(0, 73, 125), 90f);
            g.FillRectangle(fallback, ClientRectangle);
            return;
        }

        var source = CoverSourceRect(HeroImage.Size, ClientSize);
        g.DrawImage(HeroImage, ClientRectangle, source, GraphicsUnit.Pixel);
    }

    private static RectangleF CoverSourceRect(Size imageSize, Size targetSize)
    {
        var imageAspect = imageSize.Width / (float)imageSize.Height;
        var targetAspect = targetSize.Width / (float)targetSize.Height;
        if (imageAspect > targetAspect)
        {
            var width = imageSize.Height * targetAspect;
            return new RectangleF((imageSize.Width - width) / 2f, 0, width, imageSize.Height);
        }

        var height = imageSize.Width / targetAspect;
        return new RectangleF(0, (imageSize.Height - height) / 2f, imageSize.Width, height);
    }

    private static void DrawTextShadow(Graphics g, string text, Font font, PointF point, Color textColor, Color shadowColor, int offset)
    {
        using var shadowBrush = new SolidBrush(shadowColor);
        g.DrawString(text, font, shadowBrush, point.X + offset, point.Y + offset);
        using var textBrush = new SolidBrush(textColor);
        g.DrawString(text, font, textBrush, point);
    }

    private async void LauncherForm_Shown(object? sender, EventArgs e)
    {
        var progress = new Progress<UpdateProgress>(UpdateUi);
        var result = await _updater.UpdateAsync(progress, CancellationToken.None);
        _statusLabel.Text = result.Message;
        _progressBar.Value = result.Updated ? 100 : 0;
        _playButton.Enabled = result.CanPlay;
    }

    private void UpdateUi(UpdateProgress progress)
    {
        _statusLabel.Text = progress.Message;
        _progressBar.Value = Math.Clamp(progress.Percent, _progressBar.Minimum, _progressBar.Maximum);
    }

    private void PlayButton_Click(object? sender, EventArgs e)
    {
        try
        {
            _updater.LaunchWow();
            Close();
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Unable to launch Wow.exe", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
