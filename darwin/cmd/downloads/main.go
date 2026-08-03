package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path"
	"strings"
	"time"

	"github.com/media-kit/libmpv-darwin-build/pkg/lock"
)

func main() {
	lockFile := os.Args[1:][0]
	destDir := os.Args[1:][1]

	lock, err := lock.ParseLock(lockFile)
	if err != nil {
		log.Fatal(err)
	}

	for name := range lock {
		dep := lock[name]
		ext := parseExt(dep.URL, 2)

		tmpName := fmt.Sprintf(".%s-%s%s.tmp", name, dep.Version, ext)
		tmpPath := path.Join(destDir, tmpName)

		destName := fmt.Sprintf("%s-%s%s", name, dep.Version, ext)
		destPath := path.Join(destDir, destName)

		log.Println(destPath)

		err := downloadAndCheck(dep.URL, tmpPath, dep.Sha256)
		if err != nil {
			log.Fatalf("%s: %s", destPath, err)
		}

		err = os.Rename(tmpPath, destPath)
		if err != nil {
			log.Fatalf("%s: %s", destPath, err)
		}
	}
}

// downloadAndCheck retries download+checksum together. A partial download
// that returned HTTP 200 (e.g. gitlab archive URLs sometimes truncate)
// passes download() but fails check(); the retry must re-download.
func downloadAndCheck(url, path, sha256sum string) error {
	const attempts = 5
	var lastErr error
	for i := 0; i < attempts; i++ {
		if i > 0 {
			backoff := time.Duration(1<<(i-1)) * 3 * time.Second
			log.Printf("download: retry %d/%d after %s (%v)", i, attempts-1, backoff, lastErr)
			time.Sleep(backoff)
		}
		if err := downloadOnce(url, path); err != nil {
			lastErr = err
			continue
		}
		if err := check(path, sha256sum); err != nil {
			lastErr = err
			continue
		}
		return nil
	}
	return lastErr
}

func parseExt(filename string, count int) string {
	var exts []string

	for i := 0; i < count; i++ {
		ext := path.Ext(filename)
		filename = strings.TrimSuffix(filename, ext)
		exts = append(exts, ext)
	}

	return strings.Join(reverse(exts), "")
}

func reverse(s []string) []string {
	var r []string
	for i := len(s) - 1; i >= 0; i-- {
		r = append(r, s[i])
	}
	return r
}

func downloadOnce(url, path string) error {
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}
	defer file.Close()

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}
	// freedesktop.org returns HTTP 418 to requests with the default Go
	// User-Agent — set a real-looking UA to avoid the bot filter.
	req.Header.Set("User-Agent", "Mozilla/5.0 (libmpv-darwin-build)")

	client := &http.Client{Timeout: 5 * time.Minute}
	res, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return fmt.Errorf(
			"download: status error: %d!=%d", res.StatusCode, http.StatusOK,
		)
	}

	_, err = io.Copy(file, res.Body)
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}

	return nil
}

func check(path, sha256sum string) error {
	file, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("check: %w", err)
	}
	defer file.Close()

	hash := sha256.New()

	_, err = io.Copy(hash, file)
	if err != nil {
		return fmt.Errorf("check: %w", err)
	}

	sum := fmt.Sprintf("%x", hash.Sum(nil))
	if sum != sha256sum {
		// Log actual vs expected so that when a gitlab archive URL silently
		// changes tarball content (git format bump etc.), the next CI log
		// tells us what SHA to record in downloads.lock instead of failing
		// blind.
		return fmt.Errorf("check: sha256 mismatch — got %s want %s", sum, sha256sum)
	}

	return nil
}
