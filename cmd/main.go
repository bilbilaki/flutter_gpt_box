package main

import "C"
import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha1" // NEW: For hashing
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io" // NEW: For hashing
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	difflib "github.com/pmezard/go-difflib/difflib"
	bridge "hiddify.com/hiddify/bridge"
)

const (
	maxScannerBuf = 16 * 1024 * 1024
	defaultTopN   = 50
)

// ========= Data Model (Hunks) =========

type DiffLine struct {
	Type    byte   // ' ', '+', '-'
	Text    string // content without prefix
	OldLine int
	NewLine int
}

type Hunk struct {
	Header     string
	OldStart   int
	OldCount   int
	NewStart   int
	NewCount   int
	OldFile    string
	NewFile    string
	Lines      []DiffLine
	FirstMatch *MatchInfo // cached during search (mostly for original searchHunks)
}

type MatchInfo struct {
	Type       byte
	NewFile    string
	OldFile    string
	LineNumber int // new for '+', old for '-'
	MatchPos   int
}

// ========= Search Abstraction (Unified for Diff and File Search) =========

// SearchResult represents a single match from any search source (diff or file content).
type SearchResult struct {
	File       string `json:"file"`
	LineNumber int    `json:"lineNumber"`    // For diffs: NewLine for '+', OldLine for '-'; for plain files: actual line number
	LineText   string `json:"lineText"`      // The full line of text containing the match
	MatchPos   int    `json:"matchPos"`      // The start column index of the match within LineText (for highlighting)
	Score      int    `json:"score"`         // Calculated score for ranking results

	// Fields specific to diff results, nil/zero if from file content search
	DiffLine *DiffLine `json:"-"` // Pointer to the original DiffLine if this is a diff result, excluded from JSON
	Hunk     *Hunk     `json:"-"` // Pointer to the original Hunk if this is a diff result, excluded from JSON

	// NEW: Fields for AI-related search results (Phase 5)
	IsAIProposed   bool            `json:"isAIProposed,omitempty"`   // This is an AI-suggested change
	PatchID        string          `json:"patchId,omitempty"`        // Links to specific AI patch
	ChangeStatus   string          `json:"changeStatus,omitempty"`   // "proposed", "applied", "rejected"
	ValidationInfo *ValidationResult `json:"validationInfo,omitempty"` // Validation status
	RelatedPatches []string        `json:"relatedPatches,omitempty"` // Other related AI changes
}

// SearchProvider interface that can provide a list of search results.
type SearchProvider interface {
	// GetInitialResults provides an initial, unfiltered list of all potential results.
	// The query and caseSensitive parameters are used by providers that perform their
	// own initial filtering (e.g., RipgrepProvider). For others (like HunkSearchProvider),
	// they might be ignored as filtering happens in the TUI model.
	GetInitialResults(query string, caseSensitive bool) ([]SearchResult, error)
	Name() string
	IsDiffProvider() bool // To know how to display results (e.g., hunk preview vs line context)
}

// ========= Diff Provider Abstraction (internal for HunkSearchProvider) =========

type DiffProvider interface {
	Name() string
	Diff() ([]byte, error) // unified diff
}

type GitProvider struct {
	Args []string
}

var (
	runningSearches = make(map[string]context.CancelFunc)
	searchesMutex   sync.Mutex
)

// SearchConfig represents the search parameters (Modified for Phase 5)
type SearchConfig struct {
	Query         string `json:"query"`
	CaseSensitive bool   `json:"caseSensitive"`
	TopN          int    `json:"topN"`
	FromFile      string `json:"fromFile"`
	ToFile        string `json:"toFile"`
	Staged        bool   `json:"staged"`
	FindPath      string `json:"findPath"`
	Mode          string `json:"mode"`           // "diff" or "find"
	SearchID      string `json:"searchId"`       // Unique identifier for this search
	AIContext      bool   `json:"aiContext"`      // NEW (Phase 5): Include AI-generated diffs in search
	PartialDiffs   bool   `json:"partialDiffs"`   // NEW (Phase 5): Search in partial AI diffs
	AppliedPatches bool   `json:"appliedPatches"` // NEW (Phase 5): Include successfully applied patches
	PendingChanges bool   `json:"pendingChanges"` // NEW (Phase 5): Show AI-proposed but unapplied changes
}

// SearchResultResponse for returning search results (Modified for Phase 5)
type SearchResultResponse struct {
	File       string `json:"file"`
	LineNumber int    `json:"lineNumber"`
	LineText   string `json:"lineText"`
	MatchPos   int    `json:"matchPos"`
	Type       string `json:"type"` // "+", "-", " " for diffs
	Score      int    `json:"score"`
	SearchID   string `json:"searchId"`

	// NEW (Phase 5): Fields for AI-related search results
	IsAIProposed   bool            `json:"isAIProposed,omitempty"`
	PatchID        string          `json:"patchId,omitempty"`
	ChangeStatus   string          `json:"changeStatus,omitempty"`
	ValidationInfo *ValidationResult `json:"validationInfo,omitempty"`
	RelatedPatches []string        `json:"relatedPatches,omitempty"`
}

// =========================================================================
// NEW DATA MODELS FROM ROADMAP (Phase 1, 2, 3, 4, 5)
// =========================================================================

// Phase 1: File Content Indexing & Line Numbering System
type FileIndex struct {
	Path        string
	Content     string
	Lines       []IndexedLine
	LineNumbers map[string]int // Lookup: line_text -> line_number
	Hash        string
	Timestamp   time.Time
}

type IndexedLine struct {
	Number      int
	Text        string
	Hash        string
	IsEmpty     bool
	Whitespace  string
	ContentHash string
}

// Phase 2: AI-Specific Diff Format
type AIDiff struct {
	OriginalFile  FileIndex
	ModifiedFile  FileIndex
	HunkGroups    []AIHunkGroup
	ChangeSummary string
	Confidence    float64
	SuggestedFiles []string
}

type AIHunkGroup struct {
	ID             string
	Location       ChangeLocation
	OriginalLines  []int
	ModifiedLines  []int
	ChangeType     string
	ContextBefore  []IndexedLine
	ContextAfter   []IndexedLine
	OriginalCode   string
	ModifiedCode   string
	Purpose        string
	Dependencies   []string
}

type ChangeLocation struct {
	FilePath     string
	FunctionName string
	ClassName    string
	LineRange    [2]int
	Indentation  int
}

// Phase 3: AI Integration Layer
type AIRequest struct {
	TaskDescription string
	BaseFiles       []*FileIndex
	TargetFiles     []string
	ChangeContext   *AIDiff
	Constraints     []string
	StyleGuidelines string
	RelatedChanges  []AIHunkGroup
}

type AIResponse struct {
	GeneratedDiffs  []PartialDiff
	Explanations    []string
	ConfidenceScore float64
	Warnings        []string
	SuggestedFiles  []string
}

type PartialDiff struct {
	TargetFile      string
	HunkID          string
	OriginalLines   []int
	ProposedLines   []int
	ContextLines    int
	DiffContent     string        // AI-generated diff snippet
	Explanation     string        // Why this change was made
	ChangeType      string        // addition/modification/deletion
	Dependencies    []string      // Related code elements
}

// Phase 4: Intelligent Patch Application System
type PartialDiffMatcher struct {
	TargetFiles    map[string]*FileIndex
	Tolerance      float64
	MaxContext     int
	AppliedPatches map[string]bool
}

type MatchResult struct {
	FilePath      string
	OriginalLines []int
	MatchedLines  []int
	Similarity    float64
	ContextLines  int
	Confidence    float64
	IsExactMatch  bool
	SuggestedOffset int
}

type AppliedPatch struct {
	ID              string
	TargetFile      string
	OriginalLines   []int
	AppliedLines    []int
	OriginalContent string
	NewContent      string
	MatchConfidence float64
	ChangeSummary   string
	Timestamp       time.Time
	DryRun          bool
	GitPatch        string
	ValidationErrors []string
}

type ValidationResult struct {
	Type     string   // syntax, semantics, style, git
	Level    string   // error, warning, info
	Messages []string
	Fixed    bool     // Whether it can be automatically fixed
}

// PatchStore (simple in-memory for example)
type PatchStore struct {
	searchID      string
	partialDiffs  map[string]*PartialDiff
	appliedPatches map[string]*AppliedPatch
	mu            sync.Mutex
}

var (
	globalPatchStores = make(map[string]*PatchStore) // Map searchID to PatchStore
	patchStoreMutex   sync.Mutex
)

func NewPatchStore(searchID string) *PatchStore {
	patchStoreMutex.Lock()
	defer patchStoreMutex.Unlock()
	if ps, ok := globalPatchStores[searchID]; ok {
		return ps
	}
	ps := &PatchStore{
		searchID:      searchID,
		partialDiffs:  make(map[string]*PartialDiff),
		appliedPatches: make(map[string]*AppliedPatch),
	}
	globalPatchStores[searchID] = ps
	return ps
}

func GetPatchStoreForID(searchID string) *PatchStore {
	patchStoreMutex.Lock()
	defer patchStoreMutex.Unlock()
	return globalPatchStores[searchID] // May return nil if not found
}
//export GetPatchStoreStatus
func GetPatchStoreStatus(port C.longlong, searchID_ *C.char) {
    searchID := C.GoString(searchID_)
    patchStore := GetPatchStoreForID(searchID)
    
    var status map[string]interface{}
    if patchStore == nil {
        status = map[string]interface{}{
            "exists": false,
            "message": "Patch store not found",
        }
    } else {
        status = map[string]interface{}{
            "exists": true,
            "pendingDiffs": len(patchStore.partialDiffs),
            "appliedPatches": len(patchStore.appliedPatches),
        }
    }
    
    data, _ := json.Marshal(status)
    bridge.SendResponseToPort(int64(port), &bridge.DartResponse{
        Success: true,
        Data:    string(data),
    })
}

//export CleanupPatchStore
func CleanupPatchStore(searchID_ *C.char) {
    searchID := C.GoString(searchID_)
    patchStoreMutex.Lock()
    delete(globalPatchStores, searchID)
    patchStoreMutex.Unlock()
}
func (ps *PatchStore) StorePartialDiff(partial *PartialDiff) string {
	ps.mu.Lock()
	defer ps.mu.Unlock()
	id := generateHunkIDFromPartial(partial) // Generate unique ID for partial diff
	partial.HunkID = id
	ps.partialDiffs[id] = partial
	return id
}

func (ps *PatchStore) GetPartialDiff(id string) *PartialDiff {
	ps.mu.Lock()
	defer ps.mu.Unlock()
	return ps.partialDiffs[id]
}

func (ps *PatchStore) MarkAsApplied(patch *AppliedPatch) {
	ps.mu.Lock()
	defer ps.mu.Unlock()
	delete(ps.partialDiffs, patch.ID) // Remove from pending
	ps.appliedPatches[patch.ID] = patch
}

func (ps *PatchStore) GetAppliedPatches() []*AppliedPatch {
	ps.mu.Lock()
	defer ps.mu.Unlock()
	patches := make([]*AppliedPatch, 0, len(ps.appliedPatches))
	for _, p := range ps.appliedPatches {
		patches = append(patches, p)
	}
	return patches
}

func (ps *PatchStore) GetPendingDiffs() []*PartialDiff {
	ps.mu.Lock()
	defer ps.mu.Unlock()
	diffs := make([]*PartialDiff, 0, len(ps.partialDiffs))
	for _, d := range ps.partialDiffs {
		diffs = append(diffs, d)
	}
	return diffs
}

// AIDiffSearchProvider implements SearchProvider to search AI-related data (Phase 5)
type AIDiffSearchProvider struct {
	PatchStore *PatchStore
	Config     *SearchConfig
}

func (p AIDiffSearchProvider) Name() string         { return "aidiff" }
func (p AIDiffSearchProvider) IsDiffProvider() bool { return true } // Can represent diff-like changes

func (p AIDiffSearchProvider) GetInitialResults(query string, caseSensitive bool) ([]SearchResult, error) {
	var allResults []SearchResult

	normalizedQuery := query
	if !caseSensitive {
		normalizedQuery = strings.ToLower(query)
	}

	// 1. Search pending AI proposals
	if p.Config.PendingChanges && p.PatchStore != nil {
		for _, partial := range p.PatchStore.GetPendingDiffs() {
			textToSearch := partial.DiffContent + " " + partial.Explanation
			if !caseSensitive {
				textToSearch = strings.ToLower(textToSearch)
			}
			if pos := strings.Index(textToSearch, normalizedQuery); pos >= 0 || query == "" {
				allResults = append(allResults, SearchResult{
					File:         partial.TargetFile,
					LineNumber:   ternary(len(partial.OriginalLines) > 0, partial.OriginalLines[0], 0), // Representative line
					LineText:     partial.DiffContent, // Display diff content as line text
					MatchPos:     pos,
					Score:        calculatePatchScoreDummy(),
					IsAIProposed: true,
					PatchID:      partial.HunkID,
					ChangeStatus: "proposed",
				})
			}
		}
	}

	// 2. Search applied patches
	if p.Config.AppliedPatches && p.PatchStore != nil {
		for _, applied := range p.PatchStore.GetAppliedPatches() {
			textToSearch := applied.NewContent + " " + applied.ChangeSummary
			if !caseSensitive {
				textToSearch = strings.ToLower(textToSearch)
			}
			if pos := strings.Index(textToSearch, normalizedQuery); pos >= 0 || query == "" {
				allResults = append(allResults, SearchResult{
					File:         applied.TargetFile,
					LineNumber:   ternary(len(applied.AppliedLines) > 0, applied.AppliedLines[0], 0), // Representative line
					LineText:     applied.NewContent, // Display new content
					MatchPos:     pos,
					Score:        calculatePatchScoreDummy() + 100, // Bonus for applied
					IsAIProposed: true,
					PatchID:      applied.ID,
					ChangeStatus: "applied",
				})
			}
		}
	}
	// TODO: AIContext and PartialDiffs flags would involve parsing deeper into AIDiff/AIHunkGroup structures
	// For this exercise, PendingChanges and AppliedPatches cover the core bridge functionality.

	return allResults, nil
}

func calculatePatchScoreDummy() int { return 1000 } // Dummy score


// =========================================================================
// BRIDGE FUNCTIONS (Phase 6)
// =========================================================================

//export InitDartApi
func InitDartApi(api unsafe.Pointer) {
	bridge.InitDartApi(api)
}

//export StartSearch
func StartSearch(port C.longlong, configJson *C.char) {
	goConfigJson := C.GoString(configJson)

	var config SearchConfig
	err := json.Unmarshal([]byte(goConfigJson), &config)
	if err != nil {
		bridge.SendStringToPort(int64(port), "Error: Invalid config JSON - "+err.Error())
		return
	}

	// Use SearchID as the unique identifier
	searchID := config.SearchID
	if searchID == "" {
		bridge.SendStringToPort(int64(port), "Error: config must have a 'searchId'")
		return
	}

	searchesMutex.Lock()
	if _, exists := runningSearches[searchID]; exists {
		searchesMutex.Unlock()
		bridge.SendStringToPort(int64(port), "Error: A search with ID "+searchID+" is already running")
		return
	}

	ctx, cancel := context.WithCancel(context.Background())
	runningSearches[searchID] = cancel
	searchesMutex.Unlock()

	go func() {
		defer func() {
			// Clean up when done
			searchesMutex.Lock()
			delete(runningSearches, searchID)
			searchesMutex.Unlock()
		}()

		// Run the search
		results, err := runSearchLogic(ctx, &config, int64(port))

		if err != nil {
			if err != context.Canceled {
				bridge.SendStringToPort(int64(port), "Search error for "+searchID+": "+err.Error())
			}
			return
		}

		// Send results back
		response := &bridge.DartResponse{
			Success: true,
			Message: "Search completed",
		}

		data, err := json.Marshal(results)
		if err != nil {
			response.Success = false
			response.Message = "Failed to marshal results: " + err.Error()
		} else {
			response.Data = string(data)
		}

		bridge.SendResponseToPort(int64(port), response)
	}()
}

//export StopSearch
func StopSearch(searchID_ *C.char) {
	searchID := C.GoString(searchID_)

	searchesMutex.Lock()
	defer searchesMutex.Unlock()

	if cancel, exists := runningSearches[searchID]; exists {
		cancel()
		delete(runningSearches, searchID)
	}
}

// runSearchLogic encapsulates your existing search functionality (Modified for Phase 5)

//export GenerateAIContext
func GenerateAIContext(port C.longlong, requestJson *C.char) {
	goRequestJson := C.GoString(requestJson)

	var aiRequest AIRequest
	err := json.Unmarshal([]byte(goRequestJson), &aiRequest)
	if err != nil {
		bridge.SendStringToPort(int64(port), fmt.Sprintf("Error parsing AI request: %v", err))
		return
	}

	searchID := aiRequest.TaskDescription // Use task description as a unique ID for this context
	if searchID == "" {
		searchID = "ai_context_" + fmt.Sprintf("%d", time.Now().UnixNano())
	}

	// Create or retrieve patch store for this context
	patchStore := NewPatchStore(searchID)

	go func() {
		// Placeholder for AI generation logic
		// In a real implementation, this would involve:
		// 1. Formatting aiRequest into a prompt using aiRequest.FormatForAI()
		// 2. Sending the prompt to an actual AI provider (e.g., OpenAI API)
		// 3. Receiving and parsing the raw AI response

		// Mock AI response for demonstration
		mockPartialDiff := PartialDiff{
			TargetFile:   ternary(len(aiRequest.TargetFiles) > 0, aiRequest.TargetFiles[0], "mock_file.go"),
			OriginalLines: []int{10, 11, 12},
			ProposedLines: []int{10, 11, 12, 13, 14},
			ContextLines:  3,
			DiffContent:   "@@ -10,3 +10,5 @@\n // old code\n+func newAuthMiddleware() {\n+  // AI-generated auth logic\n+}\n func existingFunc() {",
			Explanation:   "Added a new authentication middleware function.",
			ChangeType:    "addition",
			Dependencies:  []string{"auth_service.go"},
		}

		aiResponse := AIResponse{
			GeneratedDiffs:  []PartialDiff{mockPartialDiff},
			Explanations:    []string{"Generated a new authentication middleware."},
			ConfidenceScore: 0.95,
			Warnings:        []string{},
			SuggestedFiles:  []string{"api/auth_routes.go"},
		}

		// Store partial diffs in the patch store
		for i := range aiResponse.GeneratedDiffs {
			aiResponse.GeneratedDiffs[i].HunkID = patchStore.StorePartialDiff(&aiResponse.GeneratedDiffs[i])
		}

		responseData, err := json.Marshal(aiResponse)
		if err != nil {
			bridge.SendStringToPort(int64(port), fmt.Sprintf("Error marshaling AI response: %v", err))
			return
		}

		response := &bridge.DartResponse{
			Success: true,
			Message: "AI context generated (mocked)",
			Data:    string(responseData),
		}
		bridge.SendResponseToPort(int64(port), response)
	}()
}

//export ApplyAIPatch
func ApplyAIPatch(port C.longlong, patchID_ *C.char, searchID_ *C.char, matchResultJson *C.char) {
	patchID := C.GoString(patchID_)
	searchID := C.GoString(searchID_)
	goMatchResultJson := C.GoString(matchResultJson)

	var matchResult MatchResult
	err := json.Unmarshal([]byte(goMatchResultJson), &matchResult)
	if err != nil {
		bridge.SendStringToPort(int64(port), fmt.Sprintf("Error parsing match result: %v", err))
		return
	}

	patchStore := GetPatchStoreForID(searchID)
	if patchStore == nil {
		bridge.SendStringToPort(int64(port), fmt.Sprintf("Error: Patch store for search ID '%s' not found.", searchID))
		return
	}

	partialDiff := patchStore.GetPartialDiff(patchID)
	if partialDiff == nil {
		bridge.SendStringToPort(int64(port), fmt.Sprintf("Error: Partial diff '%s' not found in store.", patchID))
		return
	}

	go func() {
		// Placeholder for patch application logic
		// 1. Load the target file (if not already in matcher)
		// 2. Perform fuzzy matching (if matchResult not exact)
		// 3. Apply the diff to the file content
		// 4. Update file index
		// 5. Create git patch (optional)
		// 6. Validate applied changes

		// Mock successful application
		appliedPatch := &AppliedPatch{
			ID:              patchID,
			TargetFile:      matchResult.FilePath,
			OriginalLines:   partialDiff.OriginalLines,
			AppliedLines:    matchResult.MatchedLines, // Assuming it was applied at matched lines
			OriginalContent: "mock original content",
			NewContent:      "mock new content with AI changes",
			MatchConfidence: matchResult.Confidence,
			ChangeSummary:   partialDiff.Explanation,
			Timestamp:       time.Now(),
			DryRun:          false,
			GitPatch:        "mock git diff content",
			ValidationErrors: []string{},
		}

		// Mark as applied in the store
		patchStore.MarkAsApplied(appliedPatch)

		responseData, err := json.Marshal(appliedPatch)
		if err != nil {
			bridge.SendStringToPort(int64(port), fmt.Sprintf("Error marshaling applied patch: %v", err))
			return
		}

		response := &bridge.DartResponse{
			Success: true,
			Message: fmt.Sprintf("Patch %s applied (mocked)", patchID),
			Data:    string(responseData),
		}
		bridge.SendResponseToPort(int64(port), response)
	}()
}

//export SearchAIChanges
func SearchAIChanges(port C.longlong, configJson *C.char) {
	// This function will effectively extend or re-use the existing StartSearch.
	// We ensure StartSearch and runSearchLogic are updated to handle the new SearchConfig fields.
	StartSearch(port, configJson) // Existing StartSearch will be extended
}

func (g GitProvider) Name() string { return "git" }
func (g GitProvider) Diff() ([]byte, error) {
	if _, err := exec.LookPath("git"); err != nil {
		return nil, errors.New("git not found in PATH")
	}
	cmd := exec.Command("git", append([]string{"diff", "--no-color"}, g.Args...)...)
	var out, errb bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errb
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("git diff failed: %v\n%s", err, errb.String())
	}
	return out.Bytes(), nil
}

type FilesProvider struct {
	FromPath string // optional; if empty, treat as empty file
	ToPath   string // required in pair mode; or in single file mode if FromPath empty
}

func (p FilesProvider) Name() string { return "files" }
func (p FilesProvider) Diff() ([]byte, error) {
	// Two modes:
	// 1) from-to: produce unified diff from files (pure Go)
	// 2) single file: treat all lines as "+", generate pseudo-diff
	if p.FromPath != "" && p.ToPath != "" {
		from, err := os.ReadFile(p.FromPath)
		if err != nil {
			return nil, err
		}
		to, err := os.ReadFile(p.ToPath)
		if err != nil {
			return nil, err
		}
		fromLines := splitKeepNL(string(from))
		toLines := splitKeepNL(string(to))
		ud := difflib.UnifiedDiff{
			A:        fromLines,
			B:        toLines,
			FromFile: "a/" + filepath.ToSlash(p.FromPath),
			ToFile:   "b/" + filepath.ToSlash(p.ToPath),
			Context:  3,
		}
		var buf bytes.Buffer
		if err := difflib.WriteUnifiedDiff(&buf, ud); err != nil {
			return nil, err
		}
		return buf.Bytes(), nil
	}

	// Single-file mode: index all lines as "+" against an empty old file
	if p.ToPath != "" {
		file, err := os.Open(p.ToPath)
		if err != nil {
			return nil, err
		}
		defer file.Close()
		return createPseudoDiff(file, p.ToPath)
	}

	return nil, errors.New("invalid files provider usage")
}

type StdinProvider struct {
	AsDiff bool   // if true, stdin is unified diff; else plain text to index as '+'
	NameId string // "stdin"
}

func (p StdinProvider) Name() string { return p.NameId }
func (p StdinProvider) Diff() ([]byte, error) {
	data, err := ioReadAllLimit(os.Stdin, 256*1024*1024)
	if err != nil {
		return nil, err
	}
	if p.AsDiff {
		return data, nil
	}
	// Plain text: create pseudo-diff with added lines
	return createPseudoDiff(bytes.NewReader(data), p.NameId)
}

// ========= Ripgrep Search Provider =========

// RipgrepProvider implements SearchProvider using the 'rg' command.
type RipgrepProvider struct {
	Query         string // Initial query, but TUI will re-filter
	Path          string
	CaseSensitive bool
}

func (p RipgrepProvider) Name() string         { return "ripgrep" }
func (p RipgrepProvider) IsDiffProvider() bool { return false }

func (p RipgrepProvider) GetInitialResults(query string, caseSensitive bool) ([]SearchResult, error) {
	if _, err := exec.LookPath("rg"); err != nil {
		return nil, errors.New("ripgrep (rg) not found in PATH")
	}

	args := []string{
		"--json", // CRITICAL: This gives us parseable output!
		"--line-number",
	}
	if caseSensitive {
		args = append(args, "--case-sensitive")
	} else {
		args = append(args, "--ignore-case")
	}
	args = append(args, query)
	args = append(args, p.Path) // Search path

	cmd := exec.Command("rg", args...)
	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	err := cmd.Run() // Using Run() waits for completion and captures all output
	if err != nil {
		// rg returns non-zero exit code if no matches found, but still prints JSON.
		// We only consider it a hard error if there's no stdout, or stderr has content.
		if _, ok := err.(*exec.ExitError); ok && stdoutBuf.Len() > 0 && stderrBuf.Len() == 0 {
			// Non-zero exit with matches means no actual error. Continue to parse stdout.
		} else {
			return nil, fmt.Errorf("ripgrep command failed: %v\n%s", err, stderrBuf.String())
		}
	}

	var results []SearchResult
	decoder := json.NewDecoder(&stdoutBuf)
	for decoder.More() {
		var rgMatch struct {
			Type string `json:"type"`
			Data struct {
				Path struct {
					Text string `json:"text"`
				} `json:"path"`
				LineNumber uint64 `json:"line_number"`
				Lines      struct {
					Text string `json:"text"`
				} `json:"lines"`
				Submatches []struct {
					Start uint64 `json:"start"`
				} `json:"submatches"` // For match position
			} `json:"data"`
		}
		if err := decoder.Decode(&rgMatch); err != nil {
			// Malformed JSON or other decoding error, skip and try next
			continue
		}

		if rgMatch.Type == "match" {
			matchPos := 0
			if len(rgMatch.Data.Submatches) > 0 {
				matchPos = int(rgMatch.Data.Submatches[0].Start)
			}
			results = append(results, SearchResult{
				File:       rgMatch.Data.Path.Text,
				LineNumber: int(rgMatch.Data.LineNumber),
				LineText:   strings.TrimRight(rgMatch.Data.Lines.Text, "\n"), // Remove trailing newline
				MatchPos:   matchPos,
			})
		}
	}
	return results, nil
}

// ========= Hunk Search Provider (adapts DiffProvider for SearchProvider interface) =========

// HunkSearchProvider wraps DiffProvider results into SearchResults.
type HunkSearchProvider struct {
	Hunks []Hunk
}

func (p HunkSearchProvider) Name() string         { return "diff" }
func (p HunkSearchProvider) IsDiffProvider() bool { return true }

func (p HunkSearchProvider) GetInitialResults(query string, caseSensitive bool) ([]SearchResult, error) {
	// For diffs, we generate all possible 'lines' in hunks as SearchResults.
	// The actual filtering by `query` will happen in the TUI model.
	var allResults []SearchResult
	for i := range p.Hunks {
		h := &p.Hunks[i]
		for j := range h.Lines {
			dl := &h.Lines[j]

			// Determine line number for the result
			var lineNumber int
			var file string
			if dl.Type == '+' {
				lineNumber = dl.NewLine
				file = h.NewFile
			} else if dl.Type == '-' {
				lineNumber = dl.OldLine
				file = h.OldFile
			} else { // context line
				lineNumber = dl.NewLine // or dl.OldLine, they are the same
				file = h.NewFile        // arbitrary, could be OldFile
			}

			allResults = append(allResults, SearchResult{
				File:       file,
				LineNumber: lineNumber,
				LineText:   dl.Text,
				DiffLine:   dl,
				Hunk:       h,
			})
		}
	}
	return allResults, nil
}

// ========= Diff Parsing to Hunks =========

var hunkHeaderRe = regexp.MustCompile(`^@@\s+-([0-9]+)(?:,([0-9]+))?\s+\+([0-9]+)(?:,([0-9]+))?\s+@@`)

type parseState struct {
	OldFile string
	NewFile string
	InHunk  bool
	OldLine int
	NewLine int
}

func parseUnifiedDiffToHunks(diffData []byte) ([]Hunk, error) {
	sc := bufio.NewScanner(bytes.NewReader(diffData))
	buf := make([]byte, 64*1024)
	sc.Buffer(buf, maxScannerBuf)

	var hunks []Hunk
	st := parseState{}
	var cur *Hunk

	for sc.Scan() {
		line := sc.Text()

		if strings.HasPrefix(line, "diff --git ") {
			st.InHunk = false
			fields := strings.Fields(line)
			if len(fields) >= 4 {
				af, bf := fields[len(fields)-2], fields[len(fields)-1]
				st.OldFile = stripPrefixPath(af, "a/")
				st.NewFile = stripPrefixPath(bf, "b/")
			}
			continue
		}
		if strings.HasPrefix(line, "--- ") {
			st.OldFile = stripPrefixPath(strings.TrimPrefix(line, "--- "), "a/")
			continue
		}
		if strings.HasPrefix(line, "+++ ") {
			st.NewFile = stripPrefixPath(strings.TrimPrefix(line, "+++ "), "b/")
			continue
		}
		if strings.HasPrefix(line, "@@ ") {
			m := hunkHeaderRe.FindStringSubmatch(line)
			if len(m) >= 5 {
				oldStart := atoi(m[1])
				oldCount := atoiDefault(m[2], 1)
				newStart := atoi(m[3])
				newCount := atoiDefault(m[4], 1)
				st.OldLine = oldStart
				st.NewLine = newStart
				st.InHunk = true
				h := Hunk{
					Header:   line,
					OldStart: oldStart, OldCount: oldCount,
					NewStart: newStart, NewCount: newCount,
					OldFile: st.OldFile,
					NewFile: st.NewFile,
					Lines:   make([]DiffLine, 0, oldCount+newCount),
				}
				hunks = append(hunks, h)
				cur = &hunks[len(hunks)-1]
			} else {
				st.InHunk = false
			}
			continue
		}
		if !st.InHunk || cur == nil {
			continue
		}
		if len(line) == 0 {
			continue
		}
		switch line[0] {
		case ' ':
			cur.Lines = append(cur.Lines, DiffLine{Type: ' ', Text: line[1:], OldLine: st.OldLine, NewLine: st.NewLine})
			st.OldLine++
			st.NewLine++
		case '+':
			cur.Lines = append(cur.Lines, DiffLine{Type: '+', Text: line[1:], OldLine: 0, NewLine: st.NewLine})
			st.NewLine++
		case '-':
			cur.Lines = append(cur.Lines, DiffLine{Type: '-', Text: line[1:], OldLine: st.OldLine, NewLine: 0})
			st.OldLine++
		case '\\':
			// "\ No newline at end of file" -> ignore
		default:
			// ignore
		}
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return hunks, nil
}

func stripPrefixPath(s, wantPrefix string) string {
	s = strings.TrimSpace(s)
	s = strings.Trim(s, `"`)
	if s == "/dev/null" {
		return ""
	}
	if strings.HasPrefix(s, wantPrefix) {
		return s[len(wantPrefix):]
	}
	if strings.HasPrefix(s, "a/") || strings.HasPrefix(s, "b/") {
		return s[2:]
	}
	return s
}

func atoi(s string) int {
	n, _ := strconv.Atoi(s)
	return n
}
func atoiDefault(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

// ========= TUI =========

type model struct {
	input         textinput.Model
	caseSensitive bool
	topN          int

	allSearchResults     []SearchResult // All potential search results from the provider
	currentQuery         string         // The last query that generated displaySearchResults
	displaySearchResults []SearchResult // The currently filtered and ranked results
	sel                  int            // Current selection index in displaySearchResults
	provider             SearchProvider
	status               string
	err                  error

	isDiffMode         bool   // True if the source was a diff, false for file content search
	sourceProviderName string // Name of the underlying provider (git, files, ripgrep)
}
type searchResultsMsg struct {
	results []SearchResult
	err     error
}

func performSearch(p SearchProvider, query string, caseSensitive bool) tea.Cmd {
	return func() tea.Msg {
		res, err := p.GetInitialResults(query, caseSensitive)
		return searchResultsMsg{results: res, err: err}
	}
}
func initialModel(allResults []SearchResult, caseSensitive bool, topN int, isDiffMode bool, providerName string) model {
	ti := textinput.New()
	ti.Placeholder = "Type to search in added/removed/context lines..."
	if !isDiffMode {
		ti.Placeholder = "Type to search in file content..."
	}
	ti.Focus()
	ti.CharLimit = 256
	ti.Width = 60

	m := model{
		input:              ti,
		caseSensitive:      caseSensitive,
		topN:               topN,
		allSearchResults:   allResults,
		sel:                0,
		isDiffMode:         isDiffMode,
		sourceProviderName: providerName,
	}
	// Perform initial search with an empty query to populate displaySearchResults
	m.runSearch(ti.Value())
	return m
}

func (m model) Init() tea.Cmd {
	return textinput.Blink
}

func (m *model) runSearch(query string) {
	start := time.Now()
	if query == "" {
		// If query is empty, display all initial results (up to topN if specified)
		// For diff mode, this means all lines in all hunks. For ripgrep, it's all matches.
		filtered := make([]SearchResult, 0, min(len(m.allSearchResults), m.topN))
		for _, sr := range m.allSearchResults {
			// For empty query, we set a default score to enable sorting, but it's less relevant.
			// Ripgrep mode results already have their MatchPos from rg.
			// Diff results won't have a MatchPos set by default if there's no query.
			sr.Score = 0 // Default score
			filtered = append(filtered, sr)
		}

		// Sort even with empty query to provide a consistent order
		sort.Slice(filtered, func(i, j int) bool {
			// Tie-break by file then line
			if filtered[i].File != filtered[j].File {
				return filtered[i].File < filtered[j].File
			}
			return filtered[i].LineNumber < filtered[j].LineNumber
		})

		if len(filtered) > m.topN {
			filtered = filtered[:m.topN]
		}
		m.displaySearchResults = filtered
		m.status = fmt.Sprintf("Indexed %d total results. Showing %d for empty query.", len(m.allSearchResults), len(m.displaySearchResults))

	} else {
		q := query
		if !m.caseSensitive {
			q = strings.ToLower(query)
		}

		var filteredResults []SearchResult
		for _, sr := range m.allSearchResults {
			var textToSearch string
			if m.caseSensitive {
				textToSearch = sr.LineText
			} else {
				textToSearch = strings.ToLower(sr.LineText)
			}
			if pos := strings.Index(textToSearch, q); pos >= 0 {
				sr.MatchPos = pos                     // Update MatchPos for highlighting/preview
				sr.Score = calculateScore(sr, q, pos) // Calculate score based on original logic
				filteredResults = append(filteredResults, sr)
			}
		}

		sort.Slice(filteredResults, func(i, j int) bool {
			if filteredResults[i].Score != filteredResults[j].Score {
				return filteredResults[i].Score > filteredResults[j].Score
			}
			// Tie-break by file then line
			if filteredResults[i].File != filteredResults[j].File {
				return filteredResults[i].File < filteredResults[j].File
			}
			return filteredResults[i].LineNumber < filteredResults[j].LineNumber
		})

		if len(filteredResults) > m.topN {
			filteredResults = filteredResults[:m.topN]
		}
		m.displaySearchResults = filteredResults
		m.status = fmt.Sprintf("Query: %q | %d result(s) in %.1f ms", query, len(m.displaySearchResults), float64(time.Since(start).Microseconds())/1000.0)
	}
	m.sel = 0 // Reset selection when search changes
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc":
			return m, tea.Quit
		case "up":
			if m.sel > 0 {
				m.sel--
			}
			return m, nil
		case "down":
			if m.sel+1 < len(m.displaySearchResults) {
				m.sel++
			}
			return m, nil
		case "enter":
			if len(m.displaySearchResults) == 0 {
				return m, nil
			}
			cur := m.displaySearchResults[m.sel]
			if err := openInEditor(cur.File, cur.LineNumber); err != nil {
				m.status = "Failed to open editor: " + err.Error()
			}
			return m, nil
		}
		var cmd tea.Cmd
		m.input, cmd = m.input.Update(msg)
		currentInputValue := m.input.Value()
		// Only re-run search if query has changed
		if currentInputValue != m.currentQuery {
			m.currentQuery = currentInputValue
			return m, performSearch(m.provider, m.currentQuery, m.caseSensitive)

		}
		return m, cmd
	case searchResultsMsg:
		if msg.err != nil {
			m.status = "Error: " + msg.err.Error()
			return m, nil
		}
		// This is now your main search logic, replacing runSearch
		m.allSearchResults = msg.results // Update the model's data source
		// Now filter/sort these new results for display
		m.filterAndSortResults() // A new function to handle display logic
		return m, nil
	default:
		return m, nil
	}
}

func (m model) filterAndSortResults() {
    // The provided implementation is incomplete - fix it:
    start := time.Now()
    query := m.currentQuery
    
    if query == "" {
        // Display all results with default sorting
        filtered := make([]SearchResult, len(m.allSearchResults))
        copy(filtered, m.allSearchResults)
        
        sort.Slice(filtered, func(i, j int) bool {
            if filtered[i].File != filtered[j].File {
                return filtered[i].File < filtered[j].File
            }
            return filtered[i].LineNumber < filtered[j].LineNumber
        })
        
        if len(filtered) > m.topN {
            filtered = filtered[:m.topN]
        }
        m.displaySearchResults = filtered
        m.status = fmt.Sprintf("Showing %d of %d results", len(filtered), len(m.allSearchResults))
    } else {
		q := query
        if !m.caseSensitive {
            q = strings.ToLower(query)
        }
        
        var filteredResults []SearchResult
        for _, sr := range m.allSearchResults {
            var textToSearch string
            if m.caseSensitive {
                textToSearch = sr.LineText
            } else {
                textToSearch = strings.ToLower(sr.LineText)
            }
            if pos := strings.Index(textToSearch, q); pos >= 0 {
                sr.MatchPos = pos
                sr.Score = calculateScore(sr, q, pos)
                filteredResults = append(filteredResults, sr)
            }
        }
        
        sort.Slice(filteredResults, func(i, j int) bool {
            return filteredResults[i].Score > filteredResults[j].Score
        })
        
        if len(filteredResults) > m.topN {
            filteredResults = filteredResults[:m.topN]
        }
        m.displaySearchResults = filteredResults
        m.status = fmt.Sprintf("Found %d results in %.1fms", len(filteredResults), 
            float64(time.Since(start).Microseconds())/1000.0)
    }
    m.sel = 0
}


func (m model) View() string {
	var b strings.Builder
	modeInfo := "interactive search"
	if m.isDiffMode {
		modeInfo = "interactive diff search"
	}
	fmt.Fprintf(&b, "git-idiff: %s (%s) from %s\n", modeInfo, goOSArch(), m.sourceProviderName)
	fmt.Fprintf(&b, "%s\n\n", m.status)
	fmt.Fprintf(&b, "Search: %s\n\n", m.input.View())

	if len(m.displaySearchResults) == 0 {
		b.WriteString("No matches.\n")
		return b.String()
	}
	b.WriteString("Results (Up/Down to select, Enter to open in editor):\n")
	for i, r := range m.displaySearchResults {
		prefix := "  "
		if i == m.sel {
			prefix = "> "
		}

		// Highlight the matched part of the line
		highlightedLine := r.LineText
		if r.MatchPos >= 0 && m.currentQuery != "" && r.MatchPos < len(r.LineText) { // Only highlight if there's a query and a valid match pos
			qlen := len(m.currentQuery) // Use the raw query length for display
			if !m.caseSensitive {
				qlen = len(strings.ToLower(m.currentQuery)) // Use lowercased query length for highlight bounds if case-insensitive
			}
			endPos := r.MatchPos + qlen
			if endPos > len(r.LineText) { // Ensure endPos does not exceed line length
				endPos = len(r.LineText)
			}
			highlightedLine = r.LineText[:r.MatchPos] + ansiFg(208) + r.LineText[r.MatchPos:endPos] + ansiReset + r.LineText[endPos:]
		}

		// Diff type prefix for diff results
		diffTypeChar := ' '
		if r.DiffLine != nil {
			diffTypeChar = rune(r.DiffLine.Type)
		}

		// NEW: Add AI-specific status if applicable
		aiStatus := ""
		if r.IsAIProposed {
			aiStatus = fmt.Sprintf(" [AI:%s %s]", r.ChangeStatus, r.PatchID)
		}

		fmt.Fprintf(&b, "%s%2d. %s:%d  [%c]%s  %s\n", prefix, i+1, r.File, r.LineNumber, diffTypeChar, aiStatus, truncate(highlightedLine, 120))
	}

	// Render hunk/context preview
	if len(m.displaySearchResults) > 0 {
		selectedResult := m.displaySearchResults[m.sel]
		if m.isDiffMode && selectedResult.Hunk != nil {
			b.WriteString("\nSelected hunk:\n")
			b.WriteString(renderHunkColored(selectedResult.Hunk))
		} else { // For file content search, show just the line with context
			b.WriteString(fmt.Sprintf("\nSelected line from %s:\n", selectedResult.File))
			b.WriteString(fmt.Sprintf("%d: %s\n", selectedResult.LineNumber, selectedResult.LineText))
			// NEW: If it's an AI-proposed line, show its explanation
			if selectedResult.IsAIProposed && selectedResult.PatchID != "" {
				// Use m.currentQuery as a proxy for searchID in TUI console app, or provide a dedicated one.
				// For real bridge calls, searchID is explicitly passed.
				if ps := GetPatchStoreForID(m.currentQuery); ps != nil {
					if partial := ps.GetPartialDiff(selectedResult.PatchID); partial != nil {
						b.WriteString(fmt.Sprintf("\nAI Explanation: %s\n", partial.Explanation))
					} else if applied := ps.appliedPatches[selectedResult.PatchID]; applied != nil {
						b.WriteString(fmt.Sprintf("\nAI Explanation (applied): %s\n", applied.ChangeSummary))
					}
				}
			}
		}
	}
	return b.String()
}

// New scoring helper (adapted from original searchHunks logic)
func calculateScore(sr SearchResult, q string, matchPos int) int {
	score := 10000
	if sr.Hunk != nil && sr.DiffLine != nil { // Diff-specific scoring
		switch sr.DiffLine.Type {
		case '+':
			score += 150
		case '-':
			score += 100
		}
	} else if sr.IsAIProposed { // NEW: AI-specific scoring
		score += 200 // Base score for AI suggestions
		if sr.ChangeStatus == "applied" {
			score += 50 // Bonus for applied patches
		}
	}
	score += 500 - min(matchPos, 500)
	score += 300 - min(len(sr.LineText), 300)
	return score
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

func renderHunkColored(h *Hunk) string {
	var b strings.Builder
	// colors via ANSI
	header := colorize(h.Header, ansiFg(245)) // gray
	b.WriteString(header)
	b.WriteByte('\n')
	for _, dl := range h.Lines {
		switch dl.Type {
		case '+':
			b.WriteString(ansiGreen)
			b.WriteByte('+')
			b.WriteString(dl.Text)
			b.WriteString(ansiReset)
			b.WriteByte('\n')
		case '-':
			b.WriteString(ansiRed)
			b.WriteByte('-')
			b.WriteString(dl.Text)
			b.WriteString(ansiReset)
			b.WriteByte('\n')
		default:
			// context
			b.WriteByte(' ')
			b.WriteString(dl.Text)
			b.WriteByte('\n')
		}
	}
	return b.String()
}

// ========= Editor Launcher =========

func openInEditor(file string, line int) error {

	if file == "" {
		return errors.New("no filename for selection")
	}
	// prefer VISUAL then EDITOR
	editor := os.Getenv("VISUAL")
	if editor == "" {
		editor = os.Getenv("EDITOR")
	}

	// If editor looks like VS Code or Codium
	if looksLike(editor, "code", "codium", "code-insiders") || hasInPath("code") {
		cmd := "code"
		if looksLike(editor, "codium") {
			cmd = "codium"
		} else if looksLike(editor, "code-insiders") {
			cmd = "code-insiders"
		}
		return exec.Command(cmd, "-g", fmt.Sprintf("%s:%d", file, max1(line))).Run()
	}

	// Vim/Nvim
	if looksLike(editor, "nvim", "vim") || hasInPath("nvim") || hasInPath("vim") {
		ev := editor
		if ev == "" {
			if hasInPath("nvim") {
				ev = "nvim"
			} else {
				ev = "vim"
			}
		}
		return exec.Command(ev, fmt.Sprintf("+%d", max1(line)), file).Run()
	}

	// Nano
	if looksLike(editor, "nano") || hasInPath("nano") {
		ev := editor
		if ev == "" {
			ev = "nano"
		}
		// nano +line file opens at line
		return exec.Command(ev, fmt.Sprintf("+%d", max1(line)), file).Run()
	}



	if runtime.GOOS == "windows" && (looksLike(editor, "notepad", "notepad.exe") || hasInPath("notepad.exe")) {
		return exec.Command("cmd", "/C", editor, file).Run()
	}

	// Fallback: just run editor if set, else open less
	if editor != "" {
		// It's safer to parse editor string if it can contain flags (e.g., "emacs -nw")
		// But for simple cases, this works. For complex cases, sh -c is safer but platform-dependent.
		parts := strings.Fields(editor)
		if len(parts) > 0 {
			return exec.Command(parts[0], append(parts[1:], file)...).Run()
		}
	}
	if hasInPath("less") {
		return exec.Command("less", fmt.Sprintf("+%d", max1(line)), file).Run()
	}

	// last resort: print path
	fmt.Println("Open this file at line", line, ":", file)
	return nil
}

func looksLike(s string, names ...string) bool {
	s = strings.ToLower(strings.TrimSpace(s))
	for _, n := range names {
		if s == n || strings.Contains(s, n) {
			return true
		}
	}
	return false
}

func hasInPath(bin string) bool {
	_, err := exec.LookPath(bin)
	return err == nil
}

func max1(n int) int {
	if n < 1 {
		return 1
	}
	return n
}

func runSelfTest() error {
	diff := sampleUnifiedDiff()
	hunks, err := parseUnifiedDiffToHunks([]byte(diff))
	if err != nil {
		return fmt.Errorf("parseUnifiedDiffToHunks error: %v", err)
	}
	if len(hunks) != 1 {
		return fmt.Errorf("expected 1 hunk, got %d", len(hunks))
	}
	h := hunks[0]
	if h.NewFile != "sample.go" || h.OldFile != "sample.go" {
		return fmt.Errorf("expected filename 'sample.go', got old=%q new=%q", h.OldFile, h.NewFile)
	}
	if len(h.Lines) != 4 {
		return fmt.Errorf("expected 4 lines in hunk, got %d", len(h.Lines))
	}
	// Validate line types and numbering
	var sawMinus, sawPlus bool
	for _, dl := range h.Lines {
		switch dl.Type {
		case ' ':
			if dl.OldLine == 0 || dl.NewLine == 0 {
				return fmt.Errorf("context line missing line numbers: %+v", dl)
			}
		case '-':
			sawMinus = true
			if dl.OldLine != 2 || dl.NewLine != 0 {
				return fmt.Errorf("expected '-' line at old=2, got old=%d new=%d", dl.OldLine, dl.NewLine)
			}
		case '+':
			sawPlus = true
			if dl.NewLine != 2 || dl.OldLine != 0 {
				return fmt.Errorf("expected '+' line at new=2, got new=%d old=%d", dl.NewLine, dl.OldLine)
			}
		}
	}
	if !sawMinus || !sawPlus {
		return fmt.Errorf("expected both '-' and '+' lines in hunk")
	}

	// Search test using the new SearchProvider/SearchResult model
	hunkProvider := HunkSearchProvider{Hunks: hunks}
	allResults, err := hunkProvider.GetInitialResults("newName", false)
	if err != nil {
		return fmt.Errorf("HunkSearchProvider GetInitialResults error: %v", err)
	}

	// Manual filtering and scoring for test (simulating TUI's runSearch)
	var filteredResults []SearchResult
	query := "newName"
	lowerQuery := strings.ToLower(query)
	for _, sr := range allResults {
		lowerText := strings.ToLower(sr.LineText)
		if pos := strings.Index(lowerText, lowerQuery); pos >= 0 {
			sr.MatchPos = pos
			sr.Score = calculateScore(sr, query, pos)
			filteredResults = append(filteredResults, sr)
		}
	}

	if len(filteredResults) != 1 {
		return fmt.Errorf("expected 1 search result, got %d", len(filteredResults))
	}
	if filteredResults[0].DiffLine.Type != '+' || filteredResults[0].LineNumber != 2 {
		return fmt.Errorf("unexpected result info: %+v", filteredResults[0])
	}

	// Render test (should include green color and '+newName := 2')
	rendered := renderHunkColored(&hunks[0])
	if !strings.Contains(rendered, ansiGreen) || !strings.Contains(rendered, "+newName := 2") {
		return fmt.Errorf("rendered hunk missing expected content/color")
	}

	return nil
}

func sampleUnifiedDiff() string {
	return `diff --git a/sample.go b/sample.go
--- a/sample.go
+++ b/sample.go
@@ -1,3 +1,3 @@
 package main
-oldName := 1
+newName := 2
 fmt.Println("x")
`
}

// =========================================================================
// NEW HELPER FUNCTIONS (Roadmap Implementations and Placeholders)
// =========================================================================

// --- Phase 1: File Content Indexing & Line Numbering System ---

// getLeadingWhitespace extracts leading whitespace for a line
func getLeadingWhitespace(line string) string {
	for i, r := range line {
		if !strings.ContainsRune(" \t", r) {
			return line[:i]
		}
	}
	return line // If the whole line is whitespace
}

// sha1LineHash generates a SHA1 hash for a line of text
func sha1LineHash(line string) string {
	h := sha1.New()
	io.WriteString(h, line)
	return fmt.Sprintf("%x", h.Sum(nil))
}

// sha1FileHash generates a SHA1 hash for file content
func sha1FileHash(data []byte) string {
	h := sha1.New()
	h.Write(data)
	return fmt.Sprintf("%x", h.Sum(nil))
}

// ParseFileWithMetadata reads and indexes a file for diff operations
// Placeholder: In a real implementation, this would read the file and populate all fields.
func ParseFileWithMetadata(path string) (*FileIndex, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	file := &FileIndex{
		Path:      path,
		Content:   string(data),
		Timestamp: time.Now(),
	}

	// Parse line by line
	lines := strings.Split(string(data), "\n")
	file.Lines = make([]IndexedLine, len(lines))
	file.LineNumbers = make(map[string]int)

	for i, line := range lines {
		lineNum := i + 1
		indexedLine := IndexedLine{
			Number:    lineNum,
			Text:      strings.TrimRight(line, "\r\n"),
			IsEmpty:   strings.TrimSpace(line) == "",
			Whitespace: getLeadingWhitespace(line),
		}

		// Generate multiple hashes for matching
		indexedLine.Hash = sha1LineHash(line)
		indexedLine.ContentHash = sha1LineHash(strings.TrimSpace(line))

		file.Lines[i] = indexedLine
		file.LineNumbers[line] = lineNum           // Exact match
		file.LineNumbers[strings.TrimSpace(line)] = lineNum // Normalized match
	}

	file.Hash = sha1FileHash(data)
	return file, nil
}

// FormatFileForAI returns file content with line numbers in AI-readable format
// Placeholder: In a real implementation, this formats content as described.
func (f *FileIndex) FormatForAI(includeNumbers bool, contextLines int) string {
	var sb strings.Builder

	for _, line := range f.Lines {
		lineNum := line.Number
	
		if includeNumbers {
			fmt.Fprintf(&sb, "%d |%s%s\n",
				lineNum,
				strings.Repeat(" ", 4-len(strconv.Itoa(lineNum))),
				line.Text)
		} else {
			sb.WriteString(line.Text + "\n")
		}
	}
	

	return sb.String()
}

// FormatPartialContext returns a snippet around a specific line
// Placeholder: In a real implementation, this extracts context as described.
func (f *FileIndex) FormatPartialContext(centerLine int, contextLines int) string {
	start := max(1, centerLine-contextLines)
	end := min(len(f.Lines), centerLine+contextLines)

	var sb strings.Builder
	fmt.Fprintf(&sb, "--- Context for %s around line %d ---\n", f.Path, centerLine)

	for i := start - 1; i < end; i++ {
		line := f.Lines[i]
		fmt.Fprintf(&sb, "%d |%s\n", line.Number, line.Text)
	}

	fmt.Fprintf(&sb, "--- End context ---\n")
	return sb.String()
}

// --- Phase 2: Advanced Diff Generation for AI ---

// generateChangeSummary generates a natural language summary of changes
func generateChangeSummary(aiDiff *AIDiff) string { return "mock change summary" }

// calculateChangeConfidence estimates AI confidence score for a diff
func calculateChangeConfidence(aiDiff *AIDiff) float64 { return 0.85 }

// detectRelatedFiles identifies other files that might be affected by this diff
func detectRelatedFiles(aiDiff *AIDiff) []string { return []string{"related.go"} }

// findLineInIndex finds an IndexedLine by text and number
func findLineInIndex(lines []IndexedLine, text string, number int) (IndexedLine, bool) {
	for _, line := range lines {
		if line.Number == number && line.Text == text {
			return line, true
		}
	}
	return IndexedLine{}, false
}

// getLineNumbers extracts line numbers from a slice of IndexedLine
func getLineNumbers(lines []IndexedLine) []int {
	if len(lines) == 0 {
		return nil
	}
	nums := make([]int, len(lines))
	for i, l := range lines {
		nums[i] = l.Number
	}
	return nums
}

// generateHunkID generates a unique ID for a Hunk
func generateHunkID(hunk Hunk) string {
	h := sha1.New()
	io.WriteString(h, hunk.OldFile)
	io.WriteString(h, hunk.NewFile)
	io.WriteString(h, hunk.Header)
	for _, line := range hunk.Lines {
		io.WriteString(h, string(line.Type))
		io.WriteString(h, line.Text)
	}
	return fmt.Sprintf("%x", h.Sum(nil))
}

// detectChangeLocation attempts to find the function/class context for a change
func detectChangeLocation(hunk Hunk, orig *FileIndex) ChangeLocation { return ChangeLocation{FilePath: orig.Path} }

// classifyChangeType determines if a hunk is an addition, deletion, or modification
func classifyChangeType(hunk Hunk) string { return "modification" }

// analyzeChangePurpose attempts to explain the purpose of a change
func analyzeChangePurpose(hunk Hunk, orig, mod *FileIndex) string { return "mock purpose" }

// detectDependencies identifies related code elements
func detectDependencies(hunk Hunk, orig *FileIndex) []string { return []string{"mock_dep"} }

// GenerateAIDiff creates a diff optimized for AI processing
// Placeholder: In a real implementation, this would perform semantic analysis on a diff.
func GenerateAIDiff(original, modified *FileIndex) (*AIDiff, error) {
	diff := difflib.UnifiedDiff{
		A:        splitKeepNL(original.Content),
		B:        splitKeepNL(modified.Content),
		FromFile: "a/" + filepath.Base(original.Path),
		ToFile:   "b/" + filepath.Base(modified.Path),
		Context:  5, // More context for AI understanding
	}

	var buf bytes.Buffer
	if err := difflib.WriteUnifiedDiff(&buf, diff); err != nil {
		return nil, err
	}

	// Parse the unified diff and enhance with semantic information
	hunks, err := parseUnifiedDiffToHunks(buf.Bytes())
	if err != nil {
		return nil, err
	}

	aiDiff := &AIDiff{
		OriginalFile:  *original,
		ModifiedFile:  *modified,
		HunkGroups:    make([]AIHunkGroup, 0, len(hunks)),
	}

	for _, hunk := range hunks {
		aiHunk := extractSemanticHunk(hunk, original, modified)
		aiDiff.HunkGroups = append(aiDiff.HunkGroups, aiHunk)
	}

	// Generate summary and analysis
	aiDiff.ChangeSummary = generateChangeSummary(aiDiff)
	aiDiff.Confidence = calculateChangeConfidence(aiDiff)
	aiDiff.SuggestedFiles = detectRelatedFiles(aiDiff)

	return aiDiff, nil
}

// Placeholder: In a real implementation, this extracts semantic details.
func extractSemanticHunk(hunk Hunk, orig, mod *FileIndex) AIHunkGroup {
	// Extract the core change
	var origLines, modLines []IndexedLine
	var originalCode, modifiedCode strings.Builder

	for _, line := range hunk.Lines {
		switch line.Type {
		case '+':
			if modLine, exists := findLineInIndex(mod.Lines, line.Text, line.NewLine); exists {
				modLines = append(modLines, modLine)
				fmt.Fprintf(&modifiedCode, "%d |%s\n", modLine.Number, modLine.Text)
			}
		case '-':
			if origLine, exists := findLineInIndex(orig.Lines, line.Text, line.OldLine); exists {
				origLines = append(origLines, origLine)
				fmt.Fprintf(&originalCode, "%d |%s\n", origLine.Number, origLine.Text)
			}
		}
	}

	// Add context
	contextStart := max(1, min(hunk.OldStart, hunk.NewStart)-3)
	contextEnd := min(len(orig.Lines), max(hunk.OldStart+hunk.OldCount, hunk.NewStart+hunk.NewCount)+3)

	var contextBefore []IndexedLine
	if contextStart-1 < len(orig.Lines) {
		contextBefore = orig.Lines[contextStart-1:min(len(orig.Lines), contextEnd)]
	}
	var contextAfter []IndexedLine
	if contextStart-1 < len(mod.Lines) { // Use modified lines for after context
		contextAfter = mod.Lines[contextStart-1:min(len(mod.Lines), contextEnd)]
	}

	return AIHunkGroup{
		ID:             generateHunkID(hunk),
		Location:       detectChangeLocation(hunk, orig),
		OriginalLines:  getLineNumbers(origLines),
		ModifiedLines:  getLineNumbers(modLines),
		ChangeType:     classifyChangeType(hunk),
		ContextBefore:  contextBefore,
		ContextAfter:   contextAfter,
		OriginalCode:   originalCode.String(),
		ModifiedCode:   modifiedCode.String(),
		Purpose:        analyzeChangePurpose(hunk, orig, mod),
		Dependencies:   detectDependencies(hunk, orig),
	}
}

// ExtractPartialDiff creates a focused diff for specific lines/functions
// Placeholder: In a real implementation, this would extract a relevant code snippet.
func ExtractPartialDiff(file *FileIndex, lineRange [2]int, contextLines int) *AIDiff {
	start := max(1, lineRange[0]-contextLines)
	end := min(len(file.Lines), lineRange[1]+contextLines)

	// Create pseudo-original (current file as "old")
	original := &FileIndex{
		Path:    file.Path + " (original)",
		Content: file.FormatForAI(true, 0),
		Lines:   file.Lines[start-1:end],
	}

	// Create pseudo-modified (same as original for partial extraction)
	modified := &FileIndex{
		Path:    file.Path + " (proposed)",
		Content: file.FormatForAI(true, 0),
		Lines:   file.Lines[start-1:end],
	}

	// This creates a "template" diff showing the context where AI should propose changes
	aiDiff, _ := GenerateAIDiff(original, modified)

	// Mark this as a partial template
	aiDiff.ChangeSummary = fmt.Sprintf("Template for changes around lines %d-%d in %s",
		lineRange[0], lineRange[1], file.Path)

	return aiDiff
}

// --- Phase 3: AI Integration Layer ---

// findFileInRequest finds a FileIndex within an AIRequest
func findFileInRequest(req *AIRequest, filePath string) (*FileIndex, bool) {
	for _, file := range req.BaseFiles {
		if file.Path == filePath {
			return file, true
		}
	}
	return nil, false
}

// sendToAIProvider sends the prompt to an actual AI provider
func sendToAIProvider(prompt string, req *AIRequest) (string, error) { return "mock AI response string", nil }

// AIRequest.FormatForAI creates the complete prompt for the AI model
// Placeholder: In a real implementation, this formats the prompt for the AI model.
func (req *AIRequest) FormatForAI() string {
	var sb strings.Builder

	fmt.Fprintf(&sb, "TASK: %s\n\n", req.TaskDescription)
	fmt.Fprintf(&sb, "CONSTRAINTS:\n")
	for _, constraint := range req.Constraints {
		fmt.Fprintf(&sb, "- %s\n", constraint)
	}
	fmt.Fprintf(&sb, "\nSTYLE: %s\n\n", req.StyleGuidelines)

	if req.ChangeContext != nil {
		fmt.Fprintf(&sb, "CURRENT CONTEXT:\n%s\n\n", req.ChangeContext.ChangeSummary)
	}

	fmt.Fprintf(&sb, "FILES TO MODIFY:\n")
	for _, filePath := range req.TargetFiles {
		if file, exists := findFileInRequest(req, filePath); exists {
			fmt.Fprintf(&sb, "\n=== %s ===\n", filePath)
			fmt.Fprintf(&sb, "%s", file.FormatForAI(true, 2))
		}
	}

	if len(req.RelatedChanges) > 0 {
		fmt.Fprintf(&sb, "\nRELATED CHANGES:\n")
		for _, change := range req.RelatedChanges {
			fmt.Fprintf(&sb, "\n--- %s in %s (lines %v) ---\n",
				change.ChangeType, change.Location.FilePath, change.OriginalLines)
			fmt.Fprintf(&sb, "%s", change.OriginalCode)
			fmt.Fprintf(&sb, "--- PROPOSED ---\n")
			fmt.Fprintf(&sb, "%s", change.ModifiedCode)
		}
	}

	fmt.Fprintf(&sb, "\nINSTRUCTIONS FOR RESPONSE:\n")
	fmt.Fprintf(&sb, "1. Return ONLY the modified file sections in unified diff format\n")
	fmt.Fprintf(&sb, "2. Use the exact line numbers shown above\n")
	fmt.Fprintf(&sb, "3. Include sufficient context (3-5 lines before/after each change)\n")
	fmt.Fprintf(&sb, "4. For each change, explain briefly what it does\n")
	fmt.Fprintf(&sb, "5. Preserve existing code style and indentation\n")

	return sb.String()
}

// AIHunk is a simplified struct for parsing partial diffs from AI responses
type AIHunk struct {
	OriginalLines []int
	ProposedLines []int
	ContextSize   int
}

// extractDiffSections extracts structured diffs from AI output
func extractDiffSections(aiOutput string) []struct {
	DiffText     string
	Explanation  string
	SectionStart int
	SectionEnd   int
} {
	// Placeholder: In a real implementation, this regex extracts diff hunks from text.
	hunkRegex := regexp.MustCompile(`(?s)@@\s*-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@.*?(?=(?:@@|\z))`)

	var sections []struct{ DiffText string; Explanation string; SectionStart int; SectionEnd int }
	matches := hunkRegex.FindAllStringSubmatchIndex(aiOutput, -1)

	for _, match := range matches {
		start := match[0]
		end := match[1] // The end of the matched hunk content

		diffText := aiOutput[start:end]

		// For explanation, we might look for text immediately following the diff hunk
		// or specific markers. This is a very simplistic placeholder.
		explanation := "No detailed explanation provided by AI for this hunk."
		if end < len(aiOutput) {
			// Look for next hunk or end of string, take a small snippet as potential explanation
			nextHunkMatch := hunkRegex.FindStringIndex(aiOutput[end:])
			explanationEnd := len(aiOutput)
			if nextHunkMatch != nil {
				explanationEnd = end + nextHunkMatch[0]
			}
			potentialExplanation := strings.TrimSpace(aiOutput[end:min(explanationEnd, end+200)]) // max 200 chars
			if potentialExplanation != "" && !strings.HasPrefix(potentialExplanation, "---") && !strings.HasPrefix(potentialExplanation, "+++") {
				explanation = potentialExplanation
			}
		}

		sections = append(sections, struct {
			DiffText     string
			Explanation  string
			SectionStart int
			SectionEnd   int
		}{DiffText: diffText, Explanation: explanation, SectionStart: start, SectionEnd: end})
	}

	return sections
}

// parsePartialDiff parses diff content from AI into structured line numbers
func parsePartialDiff(diffText, targetFile string) (*AIHunk, error) {
	hunks, err := parseUnifiedDiffToHunks([]byte(diffText))
	if err != nil {
		return nil, err
	}
	if len(hunks) == 0 {
		return nil, errors.New("no hunks found in partial diff text")
	}

	firstHunk := hunks[0]
	var originalLines, proposedLines []int
	contextLines := 0

	// This is a simplified approach, in a real scenario, you'd accurately track
	// line number mappings from original to new, and count context lines.
	for _, line := range firstHunk.Lines {
		switch line.Type {
		case '-':
			originalLines = append(originalLines, line.OldLine)
		case '+':
			proposedLines = append(proposedLines, line.NewLine)
		case ' ':
			contextLines++
		}
	}
	// Sort to ensure consistency
	sort.Ints(originalLines)
	sort.Ints(proposedLines)

	return &AIHunk{
		OriginalLines: originalLines,
		ProposedLines: proposedLines,
		ContextSize:   contextLines,
	}, nil
}

// classifyPartialChange classifies the type of change from a parsed AI hunk
func classifyPartialChange(parsedHunk *AIHunk) string {
	if len(parsedHunk.OriginalLines) == 0 && len(parsedHunk.ProposedLines) > 0 {
		return "addition"
	}
	if len(parsedHunk.OriginalLines) > 0 && len(parsedHunk.ProposedLines) == 0 {
		return "deletion"
	}
	if len(parsedHunk.OriginalLines) > 0 && len(parsedHunk.ProposedLines) > 0 {
		return "modification"
	}
	return "no-change"
}

// extractExplanations extracts explanations from the AI output
func extractExplanations(aiOutput string, diffs []PartialDiff) []string { return []string{"mock explanation"} }

// extractConfidenceScore extracts a confidence score from AI output
func extractConfidenceScore(aiOutput string) float64 { return 0.9 }

// extractWarnings extracts warnings from AI output
func extractWarnings(aiOutput string) []string { return []string{} }

// extractSuggestedFiles extracts suggested files from AI output
func extractSuggestedFiles(aiOutput string) []string { return []string{} }

// marshalAIResponse marshals the AIResponse to JSON
func marshalAIResponse(aiResponse *AIResponse, searchID string) string {
	// For demonstration, just marshal the response directly
	data, _ := json.Marshal(aiResponse)
	return string(data)
}

// ParseAIResponse extracts structured diffs from AI output
// Placeholder: In a real implementation, this parses the raw AI response.
func ParseAIResponse(aiOutput, targetFile string) (*AIResponse, error) {
	response := &AIResponse{
		GeneratedDiffs: make([]PartialDiff, 0),
		Explanations:   make([]string, 0),
	}

	// Use regex and heuristics to extract diff sections
	diffSections := extractDiffSections(aiOutput)

	for _, section := range diffSections {
		partialDiff := PartialDiff{
			TargetFile:  targetFile,
			DiffContent: section.DiffText,
			Explanation: section.Explanation,
		}

		// Parse the diff content to extract line numbers and context
		if parsedHunk, err := parsePartialDiff(section.DiffText, targetFile); err == nil {
			partialDiff.OriginalLines = parsedHunk.OriginalLines
			partialDiff.ProposedLines = parsedHunk.ProposedLines
			partialDiff.ContextLines = parsedHunk.ContextSize
			partialDiff.HunkID = generateHunkIDFromLines(parsedHunk.OriginalLines) // Reuse for simplicity
			partialDiff.ChangeType = classifyPartialChange(parsedHunk)

			response.GeneratedDiffs = append(response.GeneratedDiffs, partialDiff)
		} else {
			response.Warnings = append(response.Warnings, fmt.Sprintf("Failed to parse diff section for %s: %v", targetFile, err))
		}
	}

	// Extract explanations, warnings, etc. from remaining text
	response.Explanations = extractExplanations(aiOutput, response.GeneratedDiffs)
	response.ConfidenceScore = extractConfidenceScore(aiOutput)
	response.Warnings = append(response.Warnings, extractWarnings(aiOutput)...)
	response.SuggestedFiles = extractSuggestedFiles(aiOutput)

	return response, nil
}

// --- Phase 4: Intelligent Patch Application System ---

// NewPartialDiffMatcher creates a new matcher instance
func NewPartialDiffMatcher() *PartialDiffMatcher {
	return &PartialDiffMatcher{
		TargetFiles:    make(map[string]*FileIndex),
		Tolerance:      0.8,
		MaxContext:     5,
		AppliedPatches: make(map[string]bool),
	}
}

// extractContextFromPartial extracts context lines from a partial diff
func extractContextFromPartial(partial *PartialDiff) []IndexedLine { return []IndexedLine{} }

// getRepresentativeLine gets a key line from the partial diff for matching
func getRepresentativeLine(partial *PartialDiff) string {
	lines := strings.Split(partial.DiffContent, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, " ") { // Context line
			return line[1:]
		}
		if strings.HasPrefix(line, "+") { // Added line
			return line[1:]
		}
	}
	return ""
}

// similarityScore calculates string similarity


// calculateContextSimilarity calculates similarity between two sets of context lines
func calculateContextSimilarity(candidateLines, contextLines []IndexedLine) float64 {
    if len(candidateLines) == 0 || len(contextLines) == 0 {
        return 0.0
    }
    
    // Simple implementation - count matching lines
    matches := 0
    minLen := min(len(candidateLines), len(contextLines))
    
    for i := 0; i < minLen; i++ {
        if candidateLines[i].Text == contextLines[i].Text {
            matches++
        }
    }
    
    return float64(matches) / float64(minLen)
}

// Fix the similarityScore function
func similarityScore(s1, s2 string) float64 {
    if s1 == s2 {
        return 1.0
    }
    if len(s1) == 0 || len(s2) == 0 {
        return 0.0
    }
    
    // Simple Levenshtein-like similarity
    if len(s1) > len(s2) {
        s1, s2 = s2, s1
    }
    
    if strings.Contains(s2, s1) {
        return float64(len(s1)) / float64(len(s2))
    }
    
    return 0.0
}
// calculateMatchConfidence calculates confidence of a match
func calculateMatchConfidence(similarity float64, contextLen int, partial *PartialDiff) float64 { return 1.0 }

// findSemanticMatches attempts to find matches based on code structure/semantics
func (m *PartialDiffMatcher) findSemanticMatches(file *FileIndex, partial *PartialDiff) []MatchResult {
	return []MatchResult{}
}

// findStructuralLocation attempts to find matches based on code structure/AST
func (m *PartialDiffMatcher) findStructuralLocation(file *FileIndex, partial *PartialDiff) []MatchResult {
	return []MatchResult{}
}

// parsePartialDiffForApplication parses diff content for application
func parsePartialDiffForApplication(diffContent string, matchResult *MatchResult) (*AIHunk, error) {
	hunks, err := parseUnifiedDiffToHunks([]byte(diffContent))
	if err != nil {
		return nil, err
	}
	if len(hunks) == 0 {
		return nil, errors.New("no hunks found in diff content")
	}
	firstHunk := hunks[0]
	// Convert hunk lines to AIHunk format for consistency
	parsedHunk := &AIHunk{
		OriginalLines: make([]int, 0),
		ProposedLines: make([]int, 0),
	}
	for _, dl := range firstHunk.Lines {
		if dl.Type == '-' {
			parsedHunk.OriginalLines = append(parsedHunk.OriginalLines, dl.OldLine)
		} else if dl.Type == '+' {
			parsedHunk.ProposedLines = append(parsedHunk.ProposedLines, dl.NewLine)
		} else {
			parsedHunk.ContextSize++
		}
	}
	sort.Ints(parsedHunk.OriginalLines)
	sort.Ints(parsedHunk.ProposedLines)
	return parsedHunk, nil
}





// isGitRepository checks if a path is part of a Git repository
func isGitRepository(filePath string) bool {
	dir := filepath.Dir(filePath)
	cmd := exec.Command("git", "-C", dir, "rev-parse", "--is-inside-work-tree")
	err := cmd.Run()
	return err == nil
}

// createGitPatch creates a git patch
func createGitPatch(filePath, originalContent, newContent string) string { return "mock git patch" }

// validateSyntax validates code syntax
func validateSyntax(filePath, content string) []string { return []string{} }

// validateLineNumbers validates line number consistency
func validateLineNumbers(patch *AppliedPatch) []ValidationResult { return []ValidationResult{} }

// validateIndentation validates indentation consistency
func validateIndentation(patch *AppliedPatch) ValidationResult { return ValidationResult{} }

// validateSemanticChanges validates semantic changes
func validateSemanticChanges(patch *AppliedPatch) ValidationResult { return ValidationResult{} }

// validateGitPatch validates a git patch
func validateGitPatch(gitPatch string) []ValidationResult { return []ValidationResult{} }

// extractValidationErrors extracts error messages from validation results
func extractValidationErrors(results []ValidationResult) []string { return []string{} }

// marshalAppliedPatch marshals an AppliedPatch to JSON
func marshalAppliedPatch(patch *AppliedPatch) string {
	data, _ := json.Marshal(patch)
	return string(data)
}

// getCurrentLineNumbers extracts line numbers from a FileIndex (placeholder)
func getCurrentLineNumbers(file *FileIndex) []int {
	if file == nil || len(file.Lines) == 0 {
		return nil
	}
	nums := make([]int, len(file.Lines))
	for i, l := range file.Lines {
		nums[i] = l.Number
	}
	return nums
}

// PartialDiffMatcher methods from roadmap
// FindApplicationLocation locates where a partial diff should be applied
// Placeholder: In a real implementation, this would perform fuzzy matching.
func (m *PartialDiffMatcher) FindApplicationLocation(partialDiff *PartialDiff) ([]MatchResult, error) {
	var results []MatchResult

	for filePath, fileIndex := range m.TargetFiles {
		if filePath != partialDiff.TargetFile && !strings.Contains(filepath.Base(filePath), filepath.Base(partialDiff.TargetFile)) {
			continue
		}

		// Try exact line number matching first
		exactMatches := m.findExactLocation(fileIndex, partialDiff)
		if len(exactMatches) > 0 {
			for _, match := range exactMatches {
				results = append(results, MatchResult{
					FilePath:     filePath,
					OriginalLines: match.Lines,
					MatchedLines: match.Lines, // Assuming exact match means same lines
					Similarity:   1.0,
					IsExactMatch: true,
					Confidence:   1.0,
				})
			}
			continue
		}

		// Try fuzzy matching
		fuzzyMatches := m.findFuzzyLocation(fileIndex, partialDiff)
		results = append(results, fuzzyMatches...)
	}

	// Sort by confidence and similarity
	sort.Slice(results, func(i, j int) bool {
		if results[i].Confidence != results[j].Confidence {
			return results[i].Confidence > results[j].Confidence
		}
		return results[i].Similarity > results[j].Similarity
	})

	return results[:min(5, len(results))], nil // Return top 5 matches
}

// Placeholder: finds exact line matches.
// Add missing methods for PartialDiffMatcher
func (m *PartialDiffMatcher) findExactLocation(file *FileIndex, partial *PartialDiff) []struct { 
    Lines []int; Score float64; IsExact bool 
} {
    var matches []struct{ Lines []int; Score float64; IsExact bool }
    
    if len(partial.OriginalLines) > 0 {
        for _, lineNum := range partial.OriginalLines {
            if lineNum > 0 && lineNum <= len(file.Lines) {
                line := file.Lines[lineNum-1]
                repLine := getRepresentativeLine(partial)
                similarity := similarityScore(line.Text, repLine)
                
                if similarity > m.Tolerance {
                    matches = append(matches, struct{ 
                        Lines []int; Score float64; IsExact bool 
                    }{
                        Lines:   []int{lineNum},
                        Score:   similarity,
                        IsExact: true,
                    })
                }
            }
        }
    }
    
    return matches
}



// Placeholder: performs fuzzy line matching.
func (m *PartialDiffMatcher) findFuzzyLocation(file *FileIndex, partial *PartialDiff) []MatchResult {
	var results []MatchResult

	// Method 1: Search for context lines (simplified)
	contextLines := extractContextFromPartial(partial) // This is a placeholder
	if len(contextLines) == 0 && len(partial.OriginalLines) > 0 {
		// If no context extracted, use original lines as context search (simplified)
		if partial.OriginalLines[0] > 0 && partial.OriginalLines[0] <= len(file.Lines) {
			contextLines = []IndexedLine{file.Lines[partial.OriginalLines[0]-1]}
		}
	}

	if len(contextLines) > 0 {
		for i := 0; i < len(file.Lines)-len(contextLines); i++ {
			candidateLines := file.Lines[i : i+len(contextLines)]
			similarity := calculateContextSimilarity(candidateLines, contextLines)

			if similarity > m.Tolerance {
				results = append(results, MatchResult{
					FilePath:     file.Path,
					OriginalLines: getLineNumbers(candidateLines),
					MatchedLines: getLineNumbers(candidateLines),
					Similarity:   similarity,
					Confidence:   calculateMatchConfidence(similarity, len(contextLines), partial),
					ContextLines: len(contextLines),
				})
			}
		}
	}

	// Method 2: Semantic search using line hashes (placeholder)
	semanticMatches := m.findSemanticMatches(file, partial)
	results = append(results, semanticMatches...)

	// Method 3: Function/structural matching (placeholder)
	structuralMatches := m.findStructuralLocation(file, partial)
	results = append(results, structuralMatches...)

	return results
}

// ApplyPartialDiff applies an AI-generated partial diff to a target file
// Placeholder: In a real implementation, this applies the diff content.
func (m *PartialDiffMatcher) ApplyPartialDiff(partialDiff *PartialDiff, matchResult *MatchResult, dryRun bool) (*AppliedPatch, error) {
	if !dryRun && m.AppliedPatches[partialDiff.HunkID] {
		return nil, fmt.Errorf("patch %s already applied", partialDiff.HunkID)
	}

	targetFileIndex, ok := m.TargetFiles[matchResult.FilePath]
	if !ok {
		// For placeholder, try to parse from scratch if not in matcher's files
		parsedTargetFile, err := ParseFileWithMetadata(matchResult.FilePath)
		if err != nil {
			return nil, fmt.Errorf("target file not found and cannot be parsed: %s, %v", matchResult.FilePath, err)
		}
		targetFileIndex = parsedTargetFile
		m.TargetFiles[matchResult.FilePath] = targetFileIndex
	}

	// Create a backup of original content
	originalContent := targetFileIndex.Content

	// Parse the AI-generated diff
	parsedDiffHunk, err := parsePartialDiffForApplication(partialDiff.DiffContent, matchResult)
	if err != nil {
		return nil, fmt.Errorf("failed to parse AI diff: %v", err)
	}

	// Apply the diff at the matched location (placeholder logic)
	// This is a very simplistic mock; real diff application is complex (line shifts, conflicts).
	var newLines []string
	applied := false

	targetLines := strings.Split(originalContent, "\n")
	if len(targetLines) == 1 && targetLines[0] == "" { // Handle empty files
		targetLines = []string{}
	}

	if len(parsedDiffHunk.OriginalLines) > 0 && len(matchResult.MatchedLines) > 0 {
		// Assume for this mock that the diff applies directly to MatchedLines
		// Find the starting line in the target file where the change *should* occur
		// Simplistic: assume matchResult.MatchedLines[0] is the start.
		startIndex := matchResult.MatchedLines[0] - 1 // 0-indexed

		// Split the diff content into lines, removing the diff prefix characters
		diffContentLines := strings.Split(partialDiff.DiffContent, "\n")
		var changesToApply []string
		for _, line := range diffContentLines {
			if strings.HasPrefix(line, "+") || strings.HasPrefix(line, " ") {
				changesToApply = append(changesToApply, line[1:])
			} else if strings.HasPrefix(line, "-") {
				// Deletions are implied by not adding the old line
			}
		}

		// Reconstruct the file content
		if startIndex >= 0 && startIndex <= len(targetLines) {
			newLines = append(newLines, targetLines[:startIndex]...)
			newLines = append(newLines, changesToApply...) // Inject changes
			// For simplicity, assume the changes replace a block of equivalent size for modification,
			// or insert/delete if sizes differ. This mock just inserts.
			// A real implementation would carefully apply '+' and '-' lines respecting contexts.

			// Skip original lines that were supposedly modified/deleted.
			// This part is very tricky with fuzzy matching. For a mock, we'll just insert.
			// The number of lines to skip from targetLines after startIndex
			// should correspond to the number of '-' lines in the diff.
			linesToDelete := len(parsedDiffHunk.OriginalLines)
			if startIndex+linesToDelete < len(targetLines) {
				newLines = append(newLines, targetLines[startIndex+linesToDelete:]...)
			}
			applied = true
		}
	} else if len(parsedDiffHunk.ProposedLines) > 0 { // Pure addition, or no clear original context
		// This means adding new content, typically at the end or a specific line.
		// For simplicity, append to the end.
		newLines = append(newLines, targetLines...)
		diffContentLines := strings.Split(partialDiff.DiffContent, "\n")
		for _, line := range diffContentLines {
			if strings.HasPrefix(line, "+") {
				newLines = append(newLines, line[1:])
			}
		}
		applied = true
	}


	if !applied {
		return nil, fmt.Errorf("no changes were applied - location mismatch or unsupported mock application")
	}

	// Create new file content
	var newContent strings.Builder
	for i, line := range newLines {
		newContent.WriteString(line)
		if i < len(newLines)-1 || (len(newLines) == 1 && newLines[0] != "") { // Add newline unless it's the very last empty line
			newContent.WriteString("\n")
		}
	}

	appliedPatch := &AppliedPatch{
		ID:              partialDiff.HunkID,
		TargetFile:      matchResult.FilePath,
		OriginalLines:   matchResult.OriginalLines,
		AppliedLines:    getCurrentLineNumbers(targetFileIndex), // This will be the lines in the *new* content
		OriginalContent: originalContent,
		NewContent:      newContent.String(),
		MatchConfidence: matchResult.Confidence,
		ChangeSummary:   partialDiff.Explanation,
		Timestamp:       time.Now(),
		DryRun:          dryRun,
	}

	if !dryRun {
		// Actually write the file
		if err := os.WriteFile(matchResult.FilePath, []byte(newContent.String()), 0644); err != nil {
			return nil, fmt.Errorf("failed to write file: %v", err)
		}

		// Update the file index
		updatedIndex, err := ParseFileWithMetadata(matchResult.FilePath)
		if err != nil {
			return nil, fmt.Errorf("failed to reindex file: %v", err)
		}
		m.TargetFiles[matchResult.FilePath] = updatedIndex
		appliedPatch.AppliedLines = getCurrentLineNumbers(updatedIndex) // Update with actual new lines

		// Mark as applied
		m.AppliedPatches[partialDiff.HunkID] = true

		// Create Git patch if in Git repository
		if isGitRepository(matchResult.FilePath) {
			appliedPatch.GitPatch = createGitPatch(matchResult.FilePath, originalContent, newContent.String())
		}
	}

	return appliedPatch, nil
}

// ValidateAppliedPatch ensures the AI changes are safe and correct
// Placeholder: In a real implementation, this runs various checks.
func (m *PartialDiffMatcher) ValidateAppliedPatch(patch *AppliedPatch) []ValidationResult {
	var results []ValidationResult

	// 1. Syntax validation (if possible for the language)
	syntaxErrors := validateSyntax(patch.TargetFile, patch.NewContent)
	results = append(results, ValidationResult{
		Type:     "syntax",
		Level:    ternary(len(syntaxErrors) > 0, "error", "info"),
		Messages: syntaxErrors,
	})

	// 2. Line number consistency
	lineConsistency := validateLineNumbers(patch)
	results = append(results, lineConsistency...)

	// 3. Indentation consistency
	indentCheck := validateIndentation(patch)
	results = append(results, indentCheck)

	// 4. Semantic consistency (basic checks)
	semanticCheck := validateSemanticChanges(patch)
	results = append(results, semanticCheck)

	// 5. Git diff validation
	if patch.GitPatch != "" {
		gitValidation := validateGitPatch(patch.GitPatch)
		results = append(results, gitValidation...)
	}

	return results
}

// --- Phase 6: Complete Workflow Integration ---

// Fix the incomplete NewFileManager function
type FileManager struct {
    BasePath string
    Files    map[string]*FileIndex
}

func NewFileManager(path string) *FileManager {
    absPath, err := filepath.Abs(path)
    if err != nil {
        return nil
    }
    return &FileManager{
        BasePath: absPath,
        Files:    make(map[string]*FileIndex),
    }
}


// Add missing utility functions
func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}

func contains(slice []string, item string) bool {
    for _, s := range slice {
        if s == item {
            return true
        }
    }
    return false
}

func generateHunkIDFromPartial(partial *PartialDiff) string {
    if partial.HunkID != "" {
        return partial.HunkID
    }
    h := sha1.New()
    h.Write([]byte(partial.TargetFile))
    h.Write([]byte(partial.DiffContent))
    return fmt.Sprintf("hunk_%x", h.Sum(nil))[:16]
}
func LoadProjectFiles(patterns []string) ([]*FileIndex, error) {
	 //Mock implementation: 
	 return nil,nil
	mockFile, _ := ParseFileWithMetadata("mock_project/example.go")
	return []*FileIndex{mockFile}, nil
} // Placeholder
func mapFileIndices(files []*FileIndex) map[string]*FileIndex {
	fileMap := make(map[string]*FileIndex)
	for _, f := range files {
		fileMap[f.Path] = f
	}
	return fileMap
} // Placeholder
func GenerateProjectDiff(oldFiles, newFiles map[string]*FileIndex) (string, error) {
	return "mock project diff", nil
} // Placeholder
func isValidEnough(validations []ValidationResult) bool { return true } // Placeholder
func generateSearchID() string { return fmt.Sprintf("search_%d", time.Now().UnixNano()) } // Placeholder
// func generateHunkIDFromPartial(partial *PartialDiff) string {
// 	if partial.HunkID != "" {
// 		return partial.HunkID
// 	}
// 	h := sha1.New()
// 	io.WriteString(h, partial.TargetFile)
// 	io.WriteString(h, partial.DiffContent)
// 	return fmt.Sprintf("%x", h.Sum(nil))
// }
func generateHunkIDFromLines(lines []int) string {
	if len(lines) == 0 {
		return "empty_hunk"
	}
	s := ""
	for _, l := range lines {
		s += strconv.Itoa(l) + "-"
	}
	h := sha1.New()
	io.WriteString(h, s)
	return fmt.Sprintf("%x", h.Sum(nil))
}
// Fix the runSearchLogic function to handle AI provider properly
func runSearchLogic(ctx context.Context, config *SearchConfig, port int64) ([]SearchResultResponse, error) {
    var searchProvider SearchProvider
    var err error

    // Check context cancellation
    select {
    case <-ctx.Done():
        return nil, ctx.Err()
    default:
    }

    bridge.SendStringToPort(port, "Starting search for ID: "+config.SearchID)

    // AI Search Mode - Fix the logic
    useAISearch := config.AIContext || config.PartialDiffs || config.AppliedPatches || config.PendingChanges
    if useAISearch {
        patchStore := GetPatchStoreForID(config.SearchID)
        if patchStore != nil {
            aiProvider := AIDiffSearchProvider{
                PatchStore: patchStore,
                Config:     config,
            }
            searchProvider = aiProvider
            bridge.SendStringToPort(port, "Using AI diff search provider")
        } else {
            bridge.SendStringToPort(port, "Warning: AI search requested but no patch store found")
            // Don't return error here - fall through to regular search
        }
    }

    // If AI provider wasn't set or failed, use regular search
    if searchProvider == nil {

        if config.Mode == "find" {
            // Ripgrep mode
            bridge.SendStringToPort(port, "Using ripgrep mode with path: "+config.FindPath)
            rp := RipgrepProvider{
                Query:         config.Query,
                Path:          config.FindPath,
                CaseSensitive: config.CaseSensitive,
            }
            searchProvider = rp
        } else {
            // Diff mode
            var diffProvider DiffProvider

            if config.FromFile != "" && config.ToFile != "" {
                bridge.SendStringToPort(port, "Using file-to-file diff mode")
                diffProvider = FilesProvider{FromPath: config.FromFile, ToPath: config.ToFile}
            } else if config.ToFile != "" {
                bridge.SendStringToPort(port, "Using single file mode")
                diffProvider = FilesProvider{ToPath: config.ToFile}
            } else {
                // Git mode
                bridge.SendStringToPort(port, "Using git diff mode")
                gitArgs := []string{}
                if config.Staged {
                    gitArgs = append(gitArgs, "--staged")
                }
                diffProvider = GitProvider{Args: gitArgs}
            }

            diffBytes, diffErr := diffProvider.Diff()
            if diffErr != nil {
                return nil, diffErr
            }

            hunks, hunkErr := parseUnifiedDiffToHunks(diffBytes)
            if hunkErr != nil {
                return nil, hunkErr
            }

            searchProvider = HunkSearchProvider{Hunks: hunks}
        }
    }


    // Get initial results
    bridge.SendStringToPort(port, "Getting initial results...")
    allResults, err := searchProvider.GetInitialResults(config.Query, config.CaseSensitive)
    if err != nil {
        return nil, err
    }

    // Check context again
    select {
    case <-ctx.Done():
        return nil, ctx.Err()
    default:
    }

    // Filter and score results
    bridge.SendStringToPort(port, fmt.Sprintf("Filtering %d results...", len(allResults)))

    var filteredResults []SearchResult
    q := config.Query
    if !config.CaseSensitive {
        q = strings.ToLower(config.Query)
    }

    for _, sr := range allResults {
        // Check context periodically
        select {
        case <-ctx.Done():
            return nil, ctx.Err()
        default:
        }

        var textToSearch string
        if config.CaseSensitive {
            textToSearch = sr.LineText
        } else {
            textToSearch = strings.ToLower(sr.LineText)
        }

        if pos := strings.Index(textToSearch, q); pos >= 0 || config.Query == "" {
            sr.MatchPos = pos
            sr.Score = calculateScore(sr, q, pos)
            filteredResults = append(filteredResults, sr)
        }
    }

    // Sort and limit results
    bridge.SendStringToPort(port, fmt.Sprintf("Sorting %d filtered results...", len(filteredResults)))

    sort.Slice(filteredResults, func(i, j int) bool {
        if filteredResults[i].Score != filteredResults[j].Score {
            return filteredResults[i].Score > filteredResults[j].Score
        }
        if filteredResults[i].File != filteredResults[j].File {
            return filteredResults[i].File < filteredResults[j].File
        }
        return filteredResults[i].LineNumber < filteredResults[j].LineNumber
    })

    if len(filteredResults) > config.TopN {
        filteredResults = filteredResults[:config.TopN]
    }

    // Convert to response format
    var responseResults []SearchResultResponse
    for _, result := range filteredResults {
        typeChar := " "
        if result.DiffLine != nil {
            typeChar = string(result.DiffLine.Type)
        }

        responseResults = append(responseResults, SearchResultResponse{
            File:       result.File,
            LineNumber: result.LineNumber,
            LineText:   result.LineText,
            MatchPos:   result.MatchPos,
            Type:       typeChar,
            Score:      result.Score,
            SearchID:   config.SearchID,
            IsAIProposed: result.IsAIProposed, // NEW
            PatchID:      result.PatchID,      // NEW
            ChangeStatus: result.ChangeStatus, // NEW
            ValidationInfo: result.ValidationInfo, // NEW
            RelatedPatches: result.RelatedPatches, // NEW
        })
    }

    bridge.SendStringToPort(port, fmt.Sprintf("Search completed. Found %d results.", len(responseResults)))
    return responseResults, nil
}


// treating all its lines as additions.
func createPseudoDiff(r io.Reader, name string) ([]byte, error) {
	var b bytes.Buffer
	fmt.Fprintf(&b, "diff --git a/%s b/%s\n", filepath.ToSlash(name), filepath.ToSlash(name))
	fmt.Fprintf(&b, "--- /dev/null\n")
	fmt.Fprintf(&b, "+++ b/%s\n", filepath.ToSlash(name))

	var lines []string
	scanner := bufio.NewScanner(r)
	// Set buffer for scanner to handle large inputs
	buf := make([]byte, 64*1024)       // Initial buffer size
	scanner.Buffer(buf, maxScannerBuf) // Max buffer size

	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	fmt.Fprintf(&b, "@@ -0,0 +1,%d @@\n", len(lines))
	for _, ln := range lines {
		fmt.Fprintf(&b, "+%s\n", ln)
	}

	return b.Bytes(), nil
}

func splitKeepNL(s string) []string {
	// difflib expects lines including trailing newline
	lines := strings.SplitAfter(s, "\n")
	if len(lines) == 0 || (len(lines) == 1 && lines[0] == "") {
		return []string{} // Handle empty string gracefully
	}
	// If the string does not end with a newline, SplitAfter will not add an empty string.
	// If it does, the last element will be an empty string, which difflib might treat as a blank line.
	// For unified diffs, typically all lines are expected to end with a newline,
	// so SplitAfter works well.
	return lines
}

type ioLimited struct {
	r      io.Reader
	remain int64
}

func (l *ioLimited) Read(p []byte) (int, error) {
	if l.remain <= 0 {
		return 0, errors.New("input too large")
	}
	if int64(len(p)) > l.remain {
		p = p[:l.remain]
	}
	n, err := l.r.Read(p)
	l.remain -= int64(n)
	if l.remain < 0 {
		l.remain = 0
	}
	return n, err
}

func ioReadAllLimit(r io.Reader, max int64) ([]byte, error) {
	limitedReader := &ioLimited{r: r, remain: max}
	data, err := io.ReadAll(limitedReader)
	if err != nil && err != io.EOF { // io.ReadAll might return EOF as a natural end
		return nil, err
	}
	return data, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func ternary[T any](cond bool, a, b T) T {
	if cond {
		return a
	}
	return b
}

func goOSArch() string {
	return fmt.Sprintf("%s/%s • Go %s", runtime.GOOS, runtime.GOARCH, runtime.Version())
}

// ========= Main =========

func main() {
	// Flags
	topN := flag.Int("n", defaultTopN, "number of top results to display")
	caseSensitive := flag.Bool("case-sensitive", false, "case-sensitive search (default false)")
	selfTest := flag.Bool("self-test", false, "run internal parser/search/render tests and exit")
	// Diff modes (Git)
	staged := flag.Bool("staged", false, "diff staged changes vs HEAD")
	// File/StdIn modes
	fromFile := flag.String("from-file", "", "from file (for file-to-file diff)")
	toFile := flag.String("to-file", "", "to file (for file-to-file diff or single file indexing)")
	file := flag.String("file", "", "alias for --to-file (for single file indexing)")
	stdin := flag.Bool("stdin", false, "read plain text from stdin and index as added lines")
	stdinDiff := flag.Bool("stdin-diff", false, "read unified diff from stdin")
	// Ripgrep search mode
	findQuery := flag.String("find", "", "search for a pattern in files (ripgrep mode)")
	findPath := flag.String("path", ".", "path to search in --find mode")

	// NEW (Phase 5): AI-specific flags
	aiContext := flag.Bool("ai-context", false, "Include AI-generated diffs in search (implies --pending-changes and --applied-patches for console demo)")
	partialDiffs := flag.Bool("partial-diffs", false, "Search in partial AI diffs (pending changes)")
	appliedPatches := flag.Bool("applied-patches", false, "Include successfully applied AI patches in search")
	pendingChanges := flag.Bool("pending-changes", false, "Show AI-proposed but unapplied changes in search")
	runAIExample := flag.Bool("ai-example", false, "Run the AI-assisted development workflow example")


	flag.Parse()
	args := flag.Args()

	if *selfTest {
		if err := runSelfTest(); err != nil {
			fmt.Fprintln(os.Stderr, "SELF-TEST FAILED:", err)
			os.Exit(1)
		}
		fmt.Println("SELF-TEST PASSED")
		return
	}

	if *runAIExample {
		return
	}

	var searchProvider SearchProvider // Unified provider interface
	var err error

	// If AI search flags are set, create a dummy patch store for demonstration purposes
	// In a real app, this would be managed by the Dart side or a persistent store.
	dummySearchID := "console_ai_search_demo"
	if *aiContext || *partialDiffs || *appliedPatches || *pendingChanges {

		// This dummy patch store is just to make the console app runnable with AI flags.
		// The real bridge functions (GenerateAIContext, ApplyAIPatch) manage a PatchStore per search ID.
		fmt.Println("NOTE: Initializing dummy PatchStore for console AI search demo.")
		ps := NewPatchStore(dummySearchID)
		ps.StorePartialDiff(&PartialDiff{
			TargetFile: "example_ai_file.go",
			HunkID: "ai_mock_1",
			OriginalLines: []int{5},
			ProposedLines: []int{5,6,7},
			DiffContent: "@@ -5,1 +5,3 @@\n // old line\n+func AddedByAI() {\n+ // AI code\n+}\n",
			Explanation: "Mock AI addition of a function.",
			ChangeType: "addition",
		})
		appliedPatch := &AppliedPatch{
			ID: "ai_mock_applied_2",
			TargetFile: "main.go",
			OriginalContent: "fmt.Println(\"Old\")",
			NewContent: "fmt.Println(\"New AI content\")",
			AppliedLines: []int{100},
			ChangeSummary: "Mock AI modification applied.",
		}
		ps.MarkAsApplied(appliedPatch)
	}

	// NEW (Phase 5): Check for AI-related flags in main execution
	var aiFlagsSet bool = *aiContext || *partialDiffs || *appliedPatches || *pendingChanges

	if aiFlagsSet {
		// Use AIDiffSearchProvider
		searchProvider = AIDiffSearchProvider{
			PatchStore: GetPatchStoreForID(dummySearchID), // Use dummy ID for console
			Config:     &SearchConfig{ // Create a config for the console context
				Query: *findQuery,
				CaseSensitive: *caseSensitive,
				AIContext:     *aiContext,
				PartialDiffs:  *partialDiffs,
				AppliedPatches: *appliedPatches,
				PendingChanges: *pendingChanges,
			},
		}
		if searchProvider.(*AIDiffSearchProvider).PatchStore == nil {
			fmt.Fprintln(os.Stderr, "Error: AI search requested, but no PatchStore available for the dummy ID. Try starting via Dart bridge or running with --ai-example.")
			os.Exit(1)
		}
	} else if *findQuery != "" { // Ripgrep mode takes priority
		if *findPath == "" {
			*findPath = "." // Default search path for ripgrep
		}
		rp := RipgrepProvider{
			Query:         *findQuery,
			Path:          *findPath,
			CaseSensitive: *caseSensitive,
		}
		searchProvider = rp
	} else { // Diff mode (existing logic, wrapped in HunkSearchProvider)
		var diffProvider DiffProvider
		toFilePath := *toFile
		if *file != "" { // Prioritize the alias if used
			toFilePath = *file
		}

		// Choose DiffProvider by priority:
		// 1) stdin-diff
		// 2) stdin
		// 3) file-to-file
		// 4) single file
		// 5) git (modes: staged, commit(s))
		if *stdinDiff {
			diffProvider = StdinProvider{AsDiff: true, NameId: "stdin-diff"}
		} else if *stdin {
			diffProvider = StdinProvider{AsDiff: false, NameId: "stdin"}
		} else if *fromFile != "" && toFilePath != "" {
			diffProvider = FilesProvider{FromPath: *fromFile, ToPath: toFilePath}
		} else if toFilePath != "" {
			diffProvider = FilesProvider{ToPath: toFilePath}
		} else {
			// Git modes
			if _, err := exec.LookPath("git"); err == nil {
				var gitArgs []string
				if *staged {
					gitArgs = append(gitArgs, "--staged")
				}
				switch len(args) {
				case 0:
					// working tree vs HEAD
				case 1:
					// commit vs HEAD
					gitArgs = append(gitArgs, args[0], "HEAD")
				default:
					// two commits
					gitArgs = append(gitArgs, args[0], args[1])
				}
				diffProvider = GitProvider{Args: gitArgs}
			}
		}

		if diffProvider == nil {
			// No diff provider selected and no find query
			fmt.Fprintln(os.Stderr, "No input source selected. Try one of:")
			fmt.Fprintln(os.Stderr, "  git-idiff                   # working tree vs HEAD")
			fmt.Fprintln(os.Stderr, "  git-idiff --staged          # staged vs HEAD")
			fmt.Fprintln(os.Stderr, "  git-idiff <commit>          # commit vs HEAD")
			fmt.Fprintln(os.Stderr, "  git-idiff <c1> <c2>         # commit range")
			fmt.Fprintln(os.Stderr, "  git-idiff --from-file A --to-file B")
			fmt.Fprintln(os.Stderr, "  git-idiff --file FILE       # alias: --to-file FILE")
			fmt.Fprintln(os.Stderr, "  cat file | git-idiff --stdin")
			fmt.Fprintln(os.Stderr, "  cat diff.patch | git-idiff --stdin-diff")
			fmt.Fprintln(os.Stderr, "  git-idiff --find <pattern> [--path <dir>] # Ripgrep-style search")
			fmt.Fprintln(os.Stderr, "  git-idiff --applied-patches --find <pattern> # NEW: Search AI-applied changes")
			fmt.Fprintln(os.Stderr, "  git-idiff --pending-changes --find <pattern> # NEW: Search AI-proposed changes")
			fmt.Fprintln(os.Stderr, "  git-idiff --ai-example # Run a full AI-assisted development workflow example")
			os.Exit(2)
		}

		diffBytes, diffErr := diffProvider.Diff()
		if diffErr != nil {
			fmt.Fprintln(os.Stderr, "Error from provider", diffProvider.Name()+":", diffErr)
			if diffProvider.Name() == "git" {
				fmt.Fprintln(os.Stderr, "Tip: use --from-file/--to-file, --file, --stdin, --stdin-diff, or --find")
			}
			os.Exit(1)
		}
		if len(diffBytes) == 0 {
			fmt.Println("No changes found in", diffProvider.Name()+". Nothing to search.")
			return
		}

		hunks, hunkErr := parseUnifiedDiffToHunks(diffBytes)
		if hunkErr != nil {
			fmt.Fprintln(os.Stderr, "Failed to parse diff:", hunkErr)
			os.Exit(1)
		}
		if len(hunks) == 0 {
			fmt.Println("No hunks parsed. Nothing to search.")
			return
		}
		searchProvider = HunkSearchProvider{Hunks: hunks}
	} // end of provider selection

	// Get initial results from the chosen searchProvider
	// For ripgrep, this runs rg. For diff, it converts hunks to SearchResults.
	// The query here is the initial query from the --find flag, which ripgrep uses.
	// HunkSearchProvider will ignore it and generate all lines, for TUI to filter later.
	allResults, err := searchProvider.GetInitialResults(*findQuery, *caseSensitive)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Failed to get initial results from", searchProvider.Name()+":", err)
		os.Exit(1)
	}
	if len(allResults) == 0 {
		fmt.Println("No results found by", searchProvider.Name()+". Nothing to search.")
		return
	}

	p := tea.NewProgram(initialModel(allResults, *caseSensitive, *topN, searchProvider.IsDiffProvider(), searchProvider.Name()))
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "TUI error:", err)
		os.Exit(1)
	}
}

// ANSI helpers
const (
	ansiReset = "\x1b[0m"
	ansiRed   = "\x1b[31m"
	ansiGreen = "\x1b[32m"
)

func ansiFg(n int) string { return fmt.Sprintf("\x1b[38;5;%dm", n) }
func colorize(s, color string) string {
	return color + s + ansiReset
}