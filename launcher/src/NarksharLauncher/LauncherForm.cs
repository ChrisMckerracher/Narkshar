using System.Drawing.Drawing2D;

namespace NarksharLauncher;

internal sealed class LauncherForm : Form
{
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
        _statusLabel.ForeColor = Color.FromArgb(238, 219, 181);
        _statusLabel.Font = new Font("Segoe UI", 10.5f, FontStyle.Bold);
        _statusLabel.Text = "Checking Narkshar assets...";
        _statusLabel.TextAlign = ContentAlignment.MiddleLeft;
        _statusLabel.SetBounds(72, 548, 560, 28);

        _progressBar.Style = ProgressBarStyle.Continuous;
        _progressBar.Minimum = 0;
        _progressBar.Maximum = 100;
        _progressBar.Value = 0;
        _progressBar.SetBounds(72, 580, 420, 18);

        _playButton.Text = "PLAY";
        _playButton.Enabled = false;
        _playButton.Font = new Font("Segoe UI", 18f, FontStyle.Bold);
        _playButton.ForeColor = Color.FromArgb(40, 20, 5);
        _playButton.BackColor = Color.FromArgb(219, 155, 58);
        _playButton.FlatStyle = FlatStyle.Flat;
        _playButton.FlatAppearance.BorderColor = Color.FromArgb(255, 231, 155);
        _playButton.FlatAppearance.BorderSize = 1;
        _playButton.SetBounds(830, 548, 220, 62);
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

        using var background = new LinearGradientBrush(ClientRectangle, Color.FromArgb(17, 27, 33), Color.FromArgb(54, 23, 12), 25f);
        g.FillRectangle(background, ClientRectangle);

        using var glow = new SolidBrush(Color.FromArgb(95, 29, 71, 91));
        g.FillEllipse(glow, 145, 70, 480, 300);

        using var warm = new SolidBrush(Color.FromArgb(80, 171, 94, 28));
        g.FillEllipse(warm, 515, 120, 440, 350);

        using var vignette = new LinearGradientBrush(ClientRectangle, Color.FromArgb(10, 0, 0, 0), Color.FromArgb(210, 0, 0, 0), 90f);
        g.FillRectangle(vignette, ClientRectangle);

        using var framePen = new Pen(Color.FromArgb(159, 122, 66), 3);
        g.DrawRectangle(framePen, 18, 18, ClientSize.Width - 36, ClientSize.Height - 36);

        using var titleBrush = new SolidBrush(Color.FromArgb(255, 228, 166));
        using var titleFont = new Font("Georgia", 58f, FontStyle.Bold);
        g.DrawString("Narkshar", titleFont, titleBrush, 64, 382);

        using var subtitleBrush = new SolidBrush(Color.FromArgb(230, 204, 151));
        using var subtitleFont = new Font("Segoe UI", 11f, FontStyle.Bold);
        g.DrawString("Wrath 3.3.5a", subtitleFont, subtitleBrush, 72, 468);

        using var bandBrush = new SolidBrush(Color.FromArgb(215, 18, 14, 12));
        g.FillRectangle(bandBrush, 40, 528, ClientSize.Width - 80, 92);
        using var bandPen = new Pen(Color.FromArgb(115, 87, 48), 1);
        g.DrawRectangle(bandPen, 40, 528, ClientSize.Width - 80, 92);
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
